# frozen_string_literal: true

# Event class for wallet transactions to support Event Sourcing and auditing.
# Ensures state integrity by maintaining an immutable log of changes.
class WalletTransactionEvent
  attr_reader :id, :wallet_id, :event_type, :amount_cents, :timestamp, :metadata

  def initialize(id, wallet_id, event_type, amount_cents, metadata = {})
    @id = id
    @wallet_id = wallet_id
    @event_type = event_type
    @amount_cents = amount_cents
    @timestamp = Time.current
    @metadata = metadata
    freeze
  end

  def to_h
    {
      id: id,
      wallet_id: wallet_id,
      event_type: event_type,
      amount_cents: amount_cents,
      timestamp: timestamp,
      metadata: metadata
    }
  end

  def self.from_transaction(transaction)
    new(
      transaction.id,
      transaction.mobile_wallet_id,
      "transaction_#{transaction.transaction_type}",
      transaction.amount_cents,
      { status: transaction.status, source: transaction.source, purpose: transaction.purpose }
    )
  end
end