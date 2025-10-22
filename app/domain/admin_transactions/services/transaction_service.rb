# frozen_string_literal: true

module AdminTransactions
  module Services
    # Application service for orchestrating admin transaction operations
    # Provides high-level business operations while maintaining domain integrity
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class TransactionService
      # @param repository [Repositories::TransactionRepository] repository for data access
      # @param event_publisher [Infrastructure::EventPublisher] service for publishing events
      def initialize(repository: nil, event_publisher: nil)
        @repository = repository || Repositories::TransactionRepository.new
        @event_publisher = event_publisher || Infrastructure::EventPublisher.new
      end

      # Create a new admin transaction
      # @param admin_id [Integer] ID of the admin creating the transaction
      # @param requested_by_id [Integer] ID of the user requesting the transaction
      # @param approvable_type [String] polymorphic type of the object being approved
      # @param approvable_id [Integer] polymorphic ID of the object being approved
      # @param action [Symbol] the action being requested
      # @param reason [String] reason for the transaction
      # @param justification [String] detailed justification for the transaction
      # @param amount [ValueObjects::Money] monetary amount if applicable
      # @param urgency [Symbol] urgency level of the transaction
      # @param compliance_flags [Array<Symbol>] compliance requirements
      # @return [Aggregates::AdminTransaction] the created transaction
      def create_transaction(
        admin_id:,
        requested_by_id:,
        approvable_type: nil,
        approvable_id: nil,
        action:,
        reason:,
        justification: nil,
        amount: nil,
        urgency: :medium,
        compliance_flags: []
      )
        # Generate unique transaction ID
        transaction_id = generate_transaction_id

        # Create the aggregate
        transaction = Aggregates::AdminTransaction.create(
          transaction_id: transaction_id,
          admin_id: admin_id,
          requested_by_id: requested_by_id,
          approvable_type: approvable_type,
          approvable_id: approvable_id,
          action: action,
          reason: reason,
          justification: justification,
          amount: amount,
          urgency: urgency,
          compliance_flags: compliance_flags
        )

        # Save to repository
        @repository.save(transaction)

        # Publish events
        publish_events(transaction)

        transaction
      rescue => e
        handle_error(e, transaction_id)
      end

      # Request approval for a transaction
      # @param transaction_id [ValueObjects::TransactionId] ID of the transaction
      # @param approval_steps [Array<Hash>] configured approval steps
      # @param escalation_deadline [Time] when the transaction should escalate
      # @return [Aggregates::AdminTransaction] the updated transaction
      def request_approval(transaction_id, approval_steps, escalation_deadline)
        # Load the aggregate
        transaction = load_transaction(transaction_id)

        # Request approval
        transaction.request_approval(approval_steps, escalation_deadline)

        # Save to repository
        @repository.save(transaction)

        # Publish events
        publish_events(transaction)

        transaction
      rescue => e
        handle_error(e, transaction_id)
      end

      # Approve current step of a transaction
      # @param transaction_id [ValueObjects::TransactionId] ID of the transaction
      # @param approver_id [Integer] ID of the approver
      # @param comments [String] approval comments
      # @return [Aggregates::AdminTransaction] the updated transaction
      def approve_step(transaction_id, approver_id, comments = nil)
        # Load the aggregate
        transaction = load_transaction(transaction_id)

        # Approve current step
        transaction.approve_current_step(approver_id, comments)

        # Save to repository
        @repository.save(transaction)

        # Publish events
        publish_events(transaction)

        transaction
      rescue => e
        handle_error(e, transaction_id)
      end

      # Reject current step of a transaction
      # @param transaction_id [ValueObjects::TransactionId] ID of the transaction
      # @param approver_id [Integer] ID of the approver
      # @param comments [String] rejection comments
      # @return [Aggregates::AdminTransaction] the updated transaction
      def reject_step(transaction_id, approver_id, comments = nil)
        # Load the aggregate
        transaction = load_transaction(transaction_id)

        # Reject current step
        transaction.reject_current_step(approver_id, comments)

        # Save to repository
        @repository.save(transaction)

        # Publish events
        publish_events(transaction)

        transaction
      rescue => e
        handle_error(e, transaction_id)
      end

      # Escalate current step of a transaction
      # @param transaction_id [ValueObjects::TransactionId] ID of the transaction
      # @param approver_id [Integer] ID of the approver requesting escalation
      # @param comments [String] escalation comments
      # @return [Aggregates::AdminTransaction] the updated transaction
      def escalate_step(transaction_id, approver_id, comments = nil)
        # Load the aggregate
        transaction = load_transaction(transaction_id)

        # Escalate current step
        transaction.escalate_current_step(approver_id, comments)

        # Save to repository
        @repository.save(transaction)

        # Publish events
        publish_events(transaction)

        transaction
      rescue => e
        handle_error(e, transaction_id)
      end

      # Find a transaction by ID
      # @param transaction_id [ValueObjects::TransactionId] ID of the transaction
      # @return [Aggregates::AdminTransaction] the found transaction
      def find_transaction(transaction_id)
        load_transaction(transaction_id)
      rescue => e
        handle_error(e, transaction_id)
      end

      # Check if a transaction exists
      # @param transaction_id [ValueObjects::TransactionId] ID of the transaction
      # @return [Boolean] true if transaction exists
      def transaction_exists?(transaction_id)
        @repository.exists?(transaction_id)
      rescue => e
        handle_error(e, transaction_id)
        false
      end

      # Get all events for a transaction
      # @param transaction_id [ValueObjects::TransactionId] ID of the transaction
      # @return [Array<Events::DomainEvent>] all events for the transaction
      def get_transaction_events(transaction_id)
        @repository.get_events(transaction_id)
      rescue => e
        handle_error(e, transaction_id)
        []
      end

      private

      # Load a transaction from the repository
      # @param transaction_id [ValueObjects::TransactionId] ID of the transaction
      # @return [Aggregates::AdminTransaction] the loaded transaction
      def load_transaction(transaction_id)
        events = @repository.get_events(transaction_id)
        Aggregates::AdminTransaction.from_events(transaction_id, events)
      end

      # Generate a unique transaction ID
      # @return [ValueObjects::TransactionId] unique transaction identifier
      def generate_transaction_id
        loop do
          id_value = "TXN#{Time.current.strftime('%Y%m%d')}#{SecureRandom.alphanumeric(8).upcase}"
          transaction_id = ValueObjects::TransactionId.new(id_value)
          break transaction_id unless @repository.exists?(transaction_id)
        end
      end

      # Publish all uncommitted events
      # @param transaction [Aggregates::AdminTransaction] the transaction with events to publish
      def publish_events(transaction)
        transaction.events.each do |event|
          @event_publisher.publish(event)
        end
      end

      # Handle errors consistently
      # @param error [Exception] the error that occurred
      # @param transaction_id [ValueObjects::TransactionId] ID of the transaction
      def handle_error(error, transaction_id)
        # Log the error
        Rails.logger.error("Transaction service error: #{error.message}", {
          transaction_id: transaction_id&.value,
          error_class: error.class.name,
          backtrace: error.backtrace&.first(5)
        })

        # Re-raise with additional context
        raise error
      end
    end
  end
end