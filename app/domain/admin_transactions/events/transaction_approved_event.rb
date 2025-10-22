# frozen_string_literal: true

module AdminTransactions
  module Events
    # Domain event representing when a transaction is fully approved
    # This event marks the successful completion of the entire approval workflow
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class TransactionApprovedEvent < DomainEvent
      # @param transaction_id [ValueObjects::TransactionId] unique transaction identifier
      # @param approver_id [Integer] ID of the final approver
      # @param comments [String] final approval comments
      # @param metadata [Hash] additional contextual metadata
      def initialize(
        transaction_id:,
        approver_id:,
        comments: nil,
        metadata: {}
      )
        super(
          aggregate_id: transaction_id.value,
          event_id: SecureRandom.uuid,
          occurred_at: Time.current,
          metadata: metadata
        )

        @transaction_id = transaction_id
        @approver_id = approver_id
        @comments = comments&.dup&.freeze

        validate_event_data
      end

      # @return [ValueObjects::TransactionId] unique transaction identifier
      attr_reader :transaction_id

      # @return [Integer] ID of the final approver
      attr_reader :approver_id

      # @return [String] final approval comments
      attr_reader :comments

      # @return [Boolean] true if approval includes comments
      def has_comments?
        !@comments.nil?
      end

      # @return [Hash] event data for serialization
      def event_data
        {
          transaction_id: @transaction_id.value,
          approver_id: @approver_id,
          comments: @comments,
          has_comments: has_comments?
        }
      end

      private

      # Validates all required event data
      def validate_event_data
        raise ArgumentError, 'Transaction ID is required' if @transaction_id.nil?
        raise ArgumentError, 'Approver ID is required' if @approver_id.nil?
      end
    end
  end
end