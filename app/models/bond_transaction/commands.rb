# frozen_string_literal: true

require_relative 'types'

# ═══════════════════════════════════════════════════════════════════════════════════
# COMMAND LAYER: Reactive Bond Transaction Processing with CQRS
# ═══════════════════════════════════════════════════════════════════════════════════

# Immutable bond transaction command representation
ProcessBondTransactionCommand = Struct.new(
  :bond_id, :payment_transaction_id, :transaction_type, :amount_cents,
  :metadata, :priority, :timestamp, :request_id, :correlation_id, :causation_id
) do
  def self.for_bond_payment(bond, payment_transaction, priority: :normal)
    correlation_id = SecureRandom.uuid

    new(
      bond.id,
      payment_transaction.id,
      :payment,
      bond.amount_cents,
      {
        source: 'bond_payment',
        bond_type: bond.bond_type,
        payment_method: payment_transaction.transaction_type,
        correlation_id: correlation_id,
        causation_id: SecureRandom.uuid
      },
      priority,
      Time.current,
      SecureRandom.uuid,
      correlation_id,
      SecureRandom.uuid
    )
  end

  def self.for_bond_refund(bond, refund_amount_cents, priority: :high)
    correlation_id = SecureRandom.uuid

    new(
      bond.id,
      nil,
      :refund,
      refund_amount_cents,
      {
        source: 'bond_refund',
        bond_type: bond.bond_type,
        reason: 'bond_return',
        correlation_id: correlation_id,
        causation_id: SecureRandom.uuid
      },
      priority,
      Time.current,
      SecureRandom.uuid,
      correlation_id,
      SecureRandom.uuid
    )
  end

  def validate!
    raise ArgumentError, "Bond ID is required" unless bond_id.present?
    raise ArgumentError, "Transaction type is required" unless transaction_type.present?
    raise ArgumentError, "Amount must be positive" unless amount_cents&.positive?
    raise ArgumentError, "Correlation ID is required" unless correlation_id.present?
    true
  end

  def priority_level
    case priority
    when :low then 1
    when :normal then 2
    when :high then 3
    when :critical then 4
    else 2
    end
  end

  def to_event
    {
      event_id: SecureRandom.uuid,
      event_type: 'ProcessBondTransactionCommand',
      command_data: to_h,
      metadata: {
        timestamp: timestamp,
        request_id: request_id,
        correlation_id: correlation_id,
        causation_id: causation_id
      }
    }
  end
end

VerifyBondTransactionCommand = Struct.new(
  :transaction_id, :verification_type, :verification_data, :metadata, :timestamp, :correlation_id, :causation_id
) do
  def self.for_fraud_detection(transaction_id, verification_data = {})
    correlation_id = SecureRandom.uuid

    new(
      transaction_id,
      :fraud_detection,
      verification_data,
      {
        source: 'automated_verification',
        correlation_id: correlation_id,
        causation_id: SecureRandom.uuid
      },
      Time.current,
      correlation_id,
      SecureRandom.uuid
    )
  end

  def self.for_compliance_check(transaction_id, verification_data = {})
    correlation_id = SecureRandom.uuid

    new(
      transaction_id,
      :compliance_check,
      verification_data,
      {
        source: 'compliance_verification',
        correlation_id: correlation_id,
        causation_id: SecureRandom.uuid
      },
      Time.current,
      correlation_id,
      SecureRandom.uuid
    )
  end

  def validate!
    raise ArgumentError, "Transaction ID is required" unless transaction_id.present?
    raise ArgumentError, "Verification type is required" unless verification_type.present?
    raise ArgumentError, "Correlation ID is required" unless correlation_id.present?
    true
  end

  def to_event
    {
      event_id: SecureRandom.uuid,
      event_type: 'VerifyBondTransactionCommand',
      command_data: to_h,
      metadata: {
        timestamp: timestamp,
        correlation_id: correlation_id,
        causation_id: causation_id
      }
    }
  end
end