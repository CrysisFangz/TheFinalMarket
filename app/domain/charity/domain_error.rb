# frozen_string_literal: true

module Charity
  # Custom error class for domain-specific exceptions
  class DomainError < StandardError
    attr_reader :code, :details

    # Initialize domain error
    # @param message [String] error message
    # @param code [Symbol] error code for programmatic handling
    # @param details [Hash] additional error context
    def initialize(message, code = :domain_error, details = {})
      super(message)
      @code = code
      @details = details.freeze
    end

    # Create error for invalid state transitions
    # @param current_state [Symbol] current state
    # @param attempted_transition [Symbol] attempted transition
    def self.invalid_transition(current_state, attempted_transition)
      new(
        "Invalid state transition from #{current_state} via #{attempted_transition}",
        :invalid_state_transition,
        {
          current_state: current_state,
          attempted_transition: attempted_transition,
          allowed_transitions: allowed_transitions_for(current_state)
        }
      )
    end

    # Create error for business rule violations
    # @param rule [String] violated rule description
    # @param context [Hash] violation context
    def self.business_rule_violation(rule, context = {})
      new(
        "Business rule violation: #{rule}",
        :business_rule_violation,
        context.merge(rule: rule)
      )
    end

    private

    # Define allowed state transitions for charity verification
    # @param state [Symbol] current state
    # @return [Array<Symbol>] allowed transitions
    def self.allowed_transitions_for(state)
      case state
      when :pending
        %i[verify reject suspend]
      when :verified
        %i[suspend revoke escalate]
      when :rejected
        %i[reconsider]
      when :suspended
        %i[reinstate escalate revoke]
      else
        []
      end
    end
  end
end