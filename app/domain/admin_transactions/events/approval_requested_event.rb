# frozen_string_literal: true

module AdminTransactions
  module Events
    # Domain event representing when approval is requested for a transaction
    # This event triggers the approval workflow initialization
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class ApprovalRequestedEvent < DomainEvent
      # @param transaction_id [ValueObjects::TransactionId] unique transaction identifier
      # @param requested_by_id [Integer] ID of the user requesting approval
      # @param initial_status [ValueObjects::TransactionStatus] initial workflow status
      # @param approval_steps [Array<Hash>] configured approval steps
      # @param escalation_deadline [Time] when the transaction should escalate
      # @param metadata [Hash] additional contextual metadata
      def initialize(
        transaction_id:,
        requested_by_id:,
        initial_status:,
        approval_steps:,
        escalation_deadline:,
        metadata: {}
      )
        super(
          aggregate_id: transaction_id.value,
          event_id: SecureRandom.uuid,
          occurred_at: Time.current,
          metadata: metadata
        )

        @transaction_id = transaction_id
        @requested_by_id = requested_by_id
        @initial_status = initial_status
        @approval_steps = approval_steps.map(&:dup).freeze
        @escalation_deadline = escalation_deadline

        validate_event_data
      end

      # @return [ValueObjects::TransactionId] unique transaction identifier
      attr_reader :transaction_id

      # @return [Integer] ID of the user requesting approval
      attr_reader :requested_by_id

      # @return [ValueObjects::TransactionStatus] initial workflow status
      attr_reader :initial_status

      # @return [Array<Hash>] configured approval steps
      attr_reader :approval_steps

      # @return [Time] when the transaction should escalate
      attr_reader :escalation_deadline

      # @return [Hash] the first approval step configuration
      def first_approval_step
        @approval_steps.first
      end

      # @return [Boolean] true if transaction requires multiple approval steps
      def multi_step_approval?
        @approval_steps.size > 1
      end

      # @return [Array<Symbol>] all required approver roles
      def required_approver_roles
        @approval_steps.map { |step| step[:approver_role] }.uniq
      end

      # @return [Time] time until escalation (nil if already overdue)
      def time_until_escalation
        return nil if @escalation_deadline.past?

        @escalation_deadline - Time.current
      end

      # @return [Boolean] true if transaction is overdue for escalation
      def overdue_for_escalation?
        @escalation_deadline.past?
      end

      # @return [Hash] event data for serialization
      def event_data
        {
          transaction_id: @transaction_id.value,
          requested_by_id: @requested_by_id,
          initial_status: @initial_status.value,
          approval_steps_count: @approval_steps.size,
          approval_steps: @approval_steps,
          escalation_deadline: @escalation_deadline,
          multi_step_approval: multi_step_approval?,
          required_approver_roles: required_approver_roles,
          overdue_for_escalation: overdue_for_escalation?,
          time_until_escalation_seconds: time_until_escalation&.to_i
        }
      end

      private

      # Validates all required event data
      def validate_event_data
        raise ArgumentError, 'Transaction ID is required' if @transaction_id.nil?
        raise ArgumentError, 'Requested by ID is required' if @requested_by_id.nil?
        raise ArgumentError, 'Initial status is required' if @initial_status.nil?
        raise ArgumentError, 'Approval steps cannot be empty' if @approval_steps.empty?
        raise ArgumentError, 'Escalation deadline is required' if @escalation_deadline.nil?

        unless @initial_status.is_a?(ValueObjects::TransactionStatus)
          raise ArgumentError, 'Initial status must be a TransactionStatus value object'
        end

        validate_approval_steps
      end

      # Validates approval steps configuration
      def validate_approval_steps
        @approval_steps.each_with_index do |step, index|
          raise ArgumentError, "Approval step #{index} missing approver_level" unless step[:approver_level]
          raise ArgumentError, "Approval step #{index} missing approver_role" unless step[:approver_role]
          raise ArgumentError, "Approval step #{index} missing sequence_order" unless step[:sequence_order]
        end
      end
    end
  end
end