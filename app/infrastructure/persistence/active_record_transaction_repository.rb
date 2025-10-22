# frozen_string_literal: true

module Infrastructure
  module Persistence
    # ActiveRecord implementation of the transaction repository
    # Provides event sourcing persistence using ActiveRecord models
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class ActiveRecordTransactionRepository
      # Save an aggregate with all its uncommitted events
      # @param aggregate [Domain::AdminTransactions::Aggregates::AdminTransaction] the aggregate to save
      # @return [void]
      def save(aggregate)
        ActiveRecord::Base.transaction do
          # Save events to event store
          save_events_to_store(aggregate.transaction_id.value, aggregate.events, aggregate.version)

          # Update or create read model projection
          update_read_model(aggregate)
        end
      rescue => e
        Rails.logger.error("Failed to save aggregate: #{e.message}")
        raise e
      end

      # Load an aggregate by its ID
      # @param transaction_id [Domain::AdminTransactions::ValueObjects::TransactionId] the aggregate ID
      # @return [Domain::AdminTransactions::Aggregates::AdminTransaction] the loaded aggregate
      def find(transaction_id)
        events = load_events_from_store(transaction_id.value)
        Domain::AdminTransactions::Aggregates::AdminTransaction.from_events(transaction_id, events)
      end

      # Check if an aggregate exists
      # @param transaction_id [Domain::AdminTransactions::ValueObjects::TransactionId] the aggregate ID
      # @return [Boolean] true if aggregate exists
      def exists?(transaction_id)
        AdminTransactionEventStore.exists?(aggregate_id: transaction_id.value)
      end

      # Get all events for an aggregate
      # @param transaction_id [Domain::AdminTransactions::ValueObjects::TransactionId] the aggregate ID
      # @return [Array<Domain::AdminTransactions::Events::DomainEvent>] all events for the aggregate
      def get_events(transaction_id)
        load_events_from_store(transaction_id.value)
      end

      # Save events for an aggregate (for event sourcing)
      # @param aggregate_id [String] the aggregate ID
      # @param events [Array<Domain::AdminTransactions::Events::DomainEvent>] events to save
      # @param expected_version [Integer] expected current version for concurrency control
      # @return [void]
      def save_events(aggregate_id, events, expected_version)
        ActiveRecord::Base.transaction do
          # Check for concurrency conflicts
          current_version = AdminTransactionEventStore.where(aggregate_id: aggregate_id).maximum(:version) || 0

          if current_version != expected_version
            raise Domain::AdminTransactions::Exceptions::ConcurrencyError,
                  "Expected version #{expected_version}, but found #{current_version}"
          end

          # Save events
          save_events_to_store(aggregate_id, events, expected_version + 1)
        end
      end

      # Get aggregates matching criteria
      # @param criteria [Hash] search criteria
      # @return [Array<Domain::AdminTransactions::Aggregates::AdminTransaction>] matching aggregates
      def find_by_criteria(criteria)
        # Use read model for efficient querying
        query = AdminTransactionReadModel.all

        # Apply filters
        query = query.where(admin_id: criteria[:admin_id]) if criteria[:admin_id]
        query = query.where(action: criteria[:action]) if criteria[:action]
        query = query.where(status: criteria[:status]) if criteria[:status]
        query = query.where('amount >= ?', criteria[:min_amount]) if criteria[:min_amount]
        query = query.where('amount <= ?', criteria[:max_amount]) if criteria[:max_amount]
        query = query.where('created_at >= ?', criteria[:from_date]) if criteria[:from_date]
        query = query.where('created_at <= ?', criteria[:to_date]) if criteria[:to_date]

        # Load aggregates from events
        query.map do |read_model|
          transaction_id = Domain::AdminTransactions::ValueObjects::TransactionId.new(read_model.transaction_id)
          find(transaction_id)
        end
      end

      # Get count of aggregates matching criteria
      # @param criteria [Hash] search criteria
      # @return [Integer] count of matching aggregates
      def count_by_criteria(criteria)
        query = AdminTransactionReadModel.all

        # Apply same filters as find_by_criteria
        query = query.where(admin_id: criteria[:admin_id]) if criteria[:admin_id]
        query = query.where(action: criteria[:action]) if criteria[:action]
        query = query.where(status: criteria[:status]) if criteria[:status]
        query = query.where('amount >= ?', criteria[:min_amount]) if criteria[:min_amount]
        query = query.where('amount <= ?', criteria[:max_amount]) if criteria[:max_amount]
        query = query.where('created_at >= ?', criteria[:from_date]) if criteria[:from_date]
        query = query.where('created_at <= ?', criteria[:to_date]) if criteria[:to_date]

        query.count
      end

      # Delete an aggregate and all its events
      # @param transaction_id [Domain::AdminTransactions::ValueObjects::TransactionId] the aggregate ID
      # @return [void]
      def delete(transaction_id)
        ActiveRecord::Base.transaction do
          # Delete events
          AdminTransactionEventStore.where(aggregate_id: transaction_id.value).delete_all

          # Delete read model
          AdminTransactionReadModel.where(transaction_id: transaction_id.value).delete_all
        end
      end

      private

      # Save events to the event store
      # @param aggregate_id [String] the aggregate ID
      # @param events [Array<Domain::AdminTransactions::Events::DomainEvent>] events to save
      # @param version [Integer] version to assign to events
      def save_events_to_store(aggregate_id, events, version)
        events.each_with_index do |event, index|
          AdminTransactionEventStore.create!(
            aggregate_id: aggregate_id,
            event_id: event.event_id,
            event_type: event.event_type,
            event_data: event.event_data.to_json,
            version: version + index,
            occurred_at: event.occurred_at,
            metadata: event.metadata.to_json
          )
        end
      end

      # Load events from the event store
      # @param aggregate_id [String] the aggregate ID
      # @return [Array<Domain::AdminTransactions::Events::DomainEvent>] loaded events
      def load_events_from_store(aggregate_id)
        records = AdminTransactionEventStore.where(aggregate_id: aggregate_id)
                                           .order(:version)
                                           .map do |record|
          # Deserialize event based on type
          event_class = event_class_for_type(record.event_type)
          event_class.new(**record.event_data.symbolize_keys)
        end

        records
      end

      # Update the read model projection
      # @param aggregate [Domain::AdminTransactions::Aggregates::AdminTransaction] the aggregate
      def update_read_model(aggregate)
        read_model = AdminTransactionReadModel.find_or_initialize_by(
          transaction_id: aggregate.transaction_id.value
        )

        read_model.update!(
          admin_id: aggregate.admin_id,
          requested_by_id: aggregate.requested_by_id,
          approvable_type: aggregate.approvable_type,
          approvable_id: aggregate.approvable_id,
          action: aggregate.action,
          reason: aggregate.reason,
          justification: aggregate.justification,
          amount: aggregate.amount&.amount,
          currency: aggregate.amount&.currency&.iso_code,
          urgency: aggregate.urgency,
          status: aggregate.status&.value,
          compliance_flags: aggregate.compliance_flags,
          created_at: aggregate.created_at,
          updated_at: aggregate.updated_at,
          approved_by_id: aggregate.approved_by_id,
          approved_at: aggregate.approved_at,
          final_comments: aggregate.final_comments,
          version: aggregate.version
        )
      end

      # Get event class for event type
      # @param event_type [String] the event type name
      # @return [Class] the event class
      def event_class_for_type(event_type)
        "Domain::AdminTransactions::Events::#{event_type}".constantize
      rescue NameError
        Domain::AdminTransactions::Events::DomainEvent
      end
    end
  end
end