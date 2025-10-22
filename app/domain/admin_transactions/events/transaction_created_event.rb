# frozen_string_literal: true

module AdminTransactions
  module Events
    # Domain event representing the creation of a new admin transaction
    # This is an immutable fact that captures all initial transaction data
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class TransactionCreatedEvent < DomainEvent
      # @param transaction_id [ValueObjects::TransactionId] unique transaction identifier
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
      # @param metadata [Hash] additional contextual metadata
      def initialize(
        transaction_id:,
        admin_id:,
        requested_by_id:,
        approvable_type: nil,
        approvable_id: nil,
        action:,
        reason:,
        justification: nil,
        amount: nil,
        urgency: :medium,
        compliance_flags: [],
        metadata: {}
      )
        super(
          aggregate_id: transaction_id.value,
          event_id: SecureRandom.uuid,
          occurred_at: Time.current,
          metadata: metadata
        )

        @transaction_id = transaction_id
        @admin_id = admin_id
        @requested_by_id = requested_by_id || admin_id
        @approvable_type = approvable_type
        @approvable_id = approvable_id
        @action = action.to_sym
        @reason = reason.dup.freeze
        @justification = justification&.dup&.freeze
        @amount = amount
        @urgency = urgency.to_sym
        @compliance_flags = compliance_flags.map(&:to_sym).freeze

        validate_event_data
      end

      # @return [ValueObjects::TransactionId] unique transaction identifier
      attr_reader :transaction_id

      # @return [Integer] ID of the admin creating the transaction
      attr_reader :admin_id

      # @return [Integer] ID of the user requesting the transaction
      attr_reader :requested_by_id

      # @return [String] polymorphic type of the object being approved
      attr_reader :approvable_type

      # @return [Integer] polymorphic ID of the object being approved
      attr_reader :approvable_id

      # @return [Symbol] the action being requested
      attr_reader :action

      # @return [String] reason for the transaction
      attr_reader :reason

      # @return [String] detailed justification for the transaction
      attr_reader :justification

      # @return [ValueObjects::Money] monetary amount if applicable
      attr_reader :amount

      # @return [Symbol] urgency level of the transaction
      attr_reader :urgency

      # @return [Array<Symbol>] compliance requirements
      attr_reader :compliance_flags

      # @return [Boolean] true if transaction has an associated approvable object
      def has_approvable?
        !@approvable_type.nil? && !@approvable_id.nil?
      end

      # @return [Boolean] true if transaction requires justification
      def requires_justification?
        # This would typically check against transaction type configuration
        # For now, we'll assume high-value transactions require justification
        @amount.nil? || @amount.amount > 1000
      end

      # @return [Boolean] true if transaction involves financial data
      def financial_transaction?
        [:escrow_release, :escrow_refund, :payment_override].include?(@action)
      end

      # @return [Boolean] true if transaction is security-related
      def security_related?
        [:account_suspension, :account_termination, :emergency_access_grant].include?(@action)
      end

      # @return [Hash] event data for serialization
      def event_data
        {
          transaction_id: @transaction_id.value,
          admin_id: @admin_id,
          requested_by_id: @requested_by_id,
          approvable_type: @approvable_type,
          approvable_id: @approvable_id,
          action: @action,
          reason: @reason,
          justification: @justification,
          amount: @amount&.as_json,
          urgency: @urgency,
          compliance_flags: @compliance_flags,
          requires_justification: requires_justification?,
          financial_transaction: financial_transaction?,
          security_related: security_related?
        }
      end

      private

      # Validates all required event data
      def validate_event_data
        raise ArgumentError, 'Transaction ID is required' if @transaction_id.nil?
        raise ArgumentError, 'Admin ID is required' if @admin_id.nil?
        raise ArgumentError, 'Requested by ID is required' if @requested_by_id.nil?
        raise ArgumentError, 'Action is required' if @action.blank?
        raise ArgumentError, 'Reason is required' if @reason.blank?
        raise ArgumentError, 'Urgency must be valid' unless valid_urgency?(@urgency)

        if @amount && !@amount.is_a?(ValueObjects::Money)
          raise ArgumentError, 'Amount must be a Money value object'
        end

        if requires_justification? && @justification.blank?
          raise ArgumentError, 'Justification is required for this transaction type'
        end
      end

      # Validates urgency level
      # @param urgency [Symbol] urgency level to validate
      # @return [Boolean] true if valid
      def valid_urgency?(urgency)
        [:low, :medium, :high, :critical].include?(urgency)
      end
    end
  end
end