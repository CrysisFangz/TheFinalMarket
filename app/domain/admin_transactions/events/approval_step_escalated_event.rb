# frozen_string_literal: true

module AdminTransactions
  module Events
    # Domain event representing when an approval step is escalated
    # This event moves the transaction to escalated status for higher authority review
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class ApprovalStepEscalatedEvent < DomainEvent
      # @param transaction_id [ValueObjects::TransactionId] unique transaction identifier
      # @param approver_id [Integer] ID of the approver requesting escalation
      # @param step_index [Integer] index of the escalated step
      # @param comments [String] escalation comments
      # @param metadata [Hash] additional contextual metadata
      def initialize(
        transaction_id:,
        approver_id:,
        step_index:,
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
        @step_index = step_index
        @comments = comments&.dup&.freeze

        validate_event_data
      end

      # @return [ValueObjects::TransactionId] unique transaction identifier
      attr_reader :transaction_id

      # @return [Integer] ID of the approver requesting escalation
      attr_reader :approver_id

      # @return [Integer] index of the escalated step
      attr_reader :step_index

      # @return [String] escalation comments
      attr_reader :comments

      # @return [Boolean] true if escalation includes comments
      def has_comments?
        !@comments.nil?
      end

      # @return [Hash] event data for serialization
      def event_data
        {
          transaction_id: @transaction_id.value,
          approver_id: @approver_id,
          step_index: @step_index,
          comments: @comments,
          has_comments: has_comments?
        }
      end

      private

      # Validates all required event data
      def validate_event_data
        raise ArgumentError, 'Transaction ID is required' if @transaction_id.nil?
        raise ArgumentError, 'Approver ID is required' if @approver_id.nil?
        raise ArgumentError, 'Step index is required' if @step_index.nil?
        raise ArgumentError, 'Step index must be non-negative' if @step_index.negative?
      end
    end
  end
end