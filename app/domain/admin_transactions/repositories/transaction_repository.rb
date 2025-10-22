# frozen_string_literal: true

module AdminTransactions
  module Repositories
    # Repository interface for AdminTransaction aggregate persistence
    # Provides abstraction over data storage and retrieval mechanisms
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class TransactionRepository
      # Save an aggregate with all its uncommitted events
      # @param aggregate [Aggregates::AdminTransaction] the aggregate to save
      # @return [void]
      def save(aggregate)
        raise NotImplementedError, 'Subclasses must implement save'
      end

      # Load an aggregate by its ID
      # @param transaction_id [ValueObjects::TransactionId] the aggregate ID
      # @return [Aggregates::AdminTransaction] the loaded aggregate
      # @raise [AggregateNotFound] if aggregate is not found
      def find(transaction_id)
        raise NotImplementedError, 'Subclasses must implement find'
      end

      # Check if an aggregate exists
      # @param transaction_id [ValueObjects::TransactionId] the aggregate ID
      # @return [Boolean] true if aggregate exists
      def exists?(transaction_id)
        raise NotImplementedError, 'Subclasses must implement exists?'
      end

      # Get all events for an aggregate
      # @param transaction_id [ValueObjects::TransactionId] the aggregate ID
      # @return [Array<Events::DomainEvent>] all events for the aggregate
      def get_events(transaction_id)
        raise NotImplementedError, 'Subclasses must implement get_events'
      end

      # Save events for an aggregate (for event sourcing)
      # @param aggregate_id [String] the aggregate ID
      # @param events [Array<Events::DomainEvent>] events to save
      # @param expected_version [Integer] expected current version for concurrency control
      # @return [void]
      # @raise [ConcurrencyError] if expected version doesn't match current version
      def save_events(aggregate_id, events, expected_version)
        raise NotImplementedError, 'Subclasses must implement save_events'
      end

      # Get aggregates matching criteria
      # @param criteria [Hash] search criteria
      # @return [Array<Aggregates::AdminTransaction>] matching aggregates
      def find_by_criteria(criteria)
        raise NotImplementedError, 'Subclasses must implement find_by_criteria'
      end

      # Get count of aggregates matching criteria
      # @param criteria [Hash] search criteria
      # @return [Integer] count of matching aggregates
      def count_by_criteria(criteria)
        raise NotImplementedError, 'Subclasses must implement count_by_criteria'
      end

      # Delete an aggregate and all its events
      # @param transaction_id [ValueObjects::TransactionId] the aggregate ID
      # @return [void]
      def delete(transaction_id)
        raise NotImplementedError, 'Subclasses must implement delete'
      end
    end
  end
end