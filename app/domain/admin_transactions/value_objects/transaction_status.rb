# frozen_string_literal: true

module AdminTransactions
  module ValueObjects
    # Immutable value object representing transaction workflow status
    # Enforces valid state transitions and provides business logic for status validation
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class TransactionStatus
      # Valid workflow states with their metadata
      VALID_STATES = {
        draft: {
          order: 0,
          final: false,
          requires_approval: false,
          can_escalate: false,
          description: 'Initial draft state'
        },
        pending_approval: {
          order: 1,
          final: false,
          requires_approval: true,
          can_escalate: true,
          description: 'Awaiting initial approval'
        },
        under_review: {
          order: 2,
          final: false,
          requires_approval: true,
          can_escalate: true,
          description: 'Currently being reviewed'
        },
        approved: {
          order: 3,
          final: true,
          requires_approval: false,
          can_escalate: false,
          description: 'Successfully approved'
        },
        rejected: {
          order: 4,
          final: true,
          requires_approval: false,
          can_escalate: false,
          description: 'Approval rejected'
        },
        cancelled: {
          order: 5,
          final: true,
          requires_approval: false,
          can_escalate: false,
          description: 'Transaction cancelled'
        },
        escalated: {
          order: 6,
          final: false,
          requires_approval: true,
          can_escalate: true,
          description: 'Escalated for higher authority'
        },
        auto_approved: {
          order: 7,
          final: true,
          requires_approval: false,
          can_escalate: false,
          description: 'Automatically approved by system'
        }
      }.freeze

      # @param value [Symbol] the status value
      # @raise [ArgumentError] if status is invalid
      def initialize(value)
        raise ArgumentError, 'Status cannot be blank' if value.blank?
        raise ArgumentError, "Invalid status: #{value}" unless valid_status?(value)

        @value = value.to_sym.freeze
        @metadata = VALID_STATES[@value]
      end

      # @return [Symbol] the immutable status value
      attr_reader :value

      # @return [Hash] metadata for this status
      def metadata
        @metadata.dup
      end

      # @return [Boolean] true if this is a final state
      def final?
        @metadata[:final]
      end

      # @return [Boolean] true if this status requires approval
      def requires_approval?
        @metadata[:requires_approval]
      end

      # @return [Boolean] true if this status can be escalated
      def can_escalate?
        @metadata[:can_escalate]
      end

      # @return [Integer] the order/priority of this status
      def order
        @metadata[:order]
      end

      # @param other [TransactionStatus] status to compare
      # @return [Boolean] true if this status can transition to other status
      def can_transition_to?(other)
        return false unless other.is_a?(TransactionStatus)

        valid_transitions = {
          draft: [:pending_approval, :cancelled],
          pending_approval: [:under_review, :approved, :rejected, :cancelled, :escalated],
          under_review: [:approved, :rejected, :escalated],
          approved: [], # Final state
          rejected: [:pending_approval], # Can restart workflow
          cancelled: [:pending_approval], # Can restart workflow
          escalated: [:approved, :rejected, :under_review],
          auto_approved: [] # Final state
        }

        valid_transitions[@value].include?(other.value)
      end

      # @return [Boolean] true if status represents a successful completion
      def success?
        [:approved, :auto_approved].include?(@value)
      end

      # @return [Boolean] true if status represents a failure/termination
      def failure?
        [:rejected, :cancelled].include?(@value)
      end

      # @return [Boolean] true if status is in an active workflow state
      def active?
        [:pending_approval, :under_review, :escalated].include?(@value)
      end

      # @param other [TransactionStatus] object to compare
      # @return [Boolean] true if values are equal
      def ==(other)
        return false unless other.is_a?(TransactionStatus)

        value == other.value
      end
      alias eql? ==

      # @return [Integer] hash code for use in collections
      def hash
        value.hash
      end

      # @return [String] string representation of the status
      def to_s
        value.to_s
      end

      # @return [String] human-readable description
      def description
        @metadata[:description]
      end

      # @return [String] inspection string for debugging
      def inspect
        "TransactionStatus(#{value})"
      end

      private

      # Validates the status value
      # @param value [Symbol] the value to validate
      # @return [Boolean] true if status is valid
      def valid_status?(value)
        VALID_STATES.key?(value.to_sym)
      end
    end
  end
end