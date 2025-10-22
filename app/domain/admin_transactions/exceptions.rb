# frozen_string_literal: true

module AdminTransactions
  module Exceptions
    # Base exception class for admin transaction domain errors
    class DomainError < StandardError
      # @param message [String] error message
      # @param transaction_id [String] ID of the transaction that caused the error
      def initialize(message, transaction_id = nil)
        super(message)
        @transaction_id = transaction_id
      end

      # @return [String] ID of the transaction that caused the error
      attr_reader :transaction_id
    end

    # Exception raised when attempting an invalid state transition
    class InvalidStateTransition < DomainError
      # @param message [String] error message
      # @param transaction_id [String] ID of the transaction
      # @param current_state [Symbol] current state of the transaction
      # @param attempted_state [Symbol] state that was attempted
      def initialize(message, transaction_id = nil, current_state: nil, attempted_state: nil)
        super(message, transaction_id)
        @current_state = current_state
        @attempted_state = attempted_state
      end

      # @return [Symbol] current state of the transaction
      attr_reader :current_state

      # @return [Symbol] state that was attempted
      attr_reader :attempted_state
    end

    # Exception raised when an approver lacks authority for an action
    class UnauthorizedApprover < DomainError
      # @param message [String] error message
      # @param transaction_id [String] ID of the transaction
      # @param approver_id [Integer] ID of the unauthorized approver
      # @param required_role [Symbol] role required for the action
      def initialize(message, transaction_id = nil, approver_id: nil, required_role: nil)
        super(message, transaction_id)
        @approver_id = approver_id
        @required_role = required_role
      end

      # @return [Integer] ID of the unauthorized approver
      attr_reader :approver_id

      # @return [Symbol] role required for the action
      attr_reader :required_role
    end

    # Exception raised when transaction validation fails
    class ValidationError < DomainError
      # @param message [String] error message
      # @param transaction_id [String] ID of the transaction
      # @param validation_errors [Hash] detailed validation errors
      def initialize(message, transaction_id = nil, validation_errors: {})
        super(message, transaction_id)
        @validation_errors = validation_errors
      end

      # @return [Hash] detailed validation errors
      attr_reader :validation_errors
    end

    # Exception raised when compliance requirements are not met
    class ComplianceError < DomainError
      # @param message [String] error message
      # @param transaction_id [String] ID of the transaction
      # @param missing_flags [Array<Symbol>] compliance flags that are missing
      def initialize(message, transaction_id = nil, missing_flags: [])
        super(message, transaction_id)
        @missing_flags = missing_flags
      end

      # @return [Array<Symbol>] compliance flags that are missing
      attr_reader :missing_flags
    end

    # Exception raised when risk assessment fails
    class RiskAssessmentError < DomainError
      # @param message [String] error message
      # @param transaction_id [String] ID of the transaction
      # @param risk_score [Float] calculated risk score
      # @param risk_threshold [Float] threshold that was exceeded
      def initialize(message, transaction_id = nil, risk_score: nil, risk_threshold: nil)
        super(message, transaction_id)
        @risk_score = risk_score
        @risk_threshold = risk_threshold
      end

      # @return [Float] calculated risk score
      attr_reader :risk_score

      # @return [Float] threshold that was exceeded
      attr_reader :risk_threshold
    end
  end
end