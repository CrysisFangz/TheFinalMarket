# frozen_string_literal: true

# Service class for handling wallet transaction business logic, decoupled from the model.
# Ensures separation of concerns and enables easier testing and scalability.
class WalletTransactionService
  class TransactionError < StandardError; end

  def self.create_transaction(wallet, type, amount_cents, source: nil, purpose: nil)
    transaction = wallet.wallet_transactions.build(
      transaction_type: type,
      amount_cents: amount_cents,
      source: source,
      purpose: purpose,
      status: :pending
    )

    transaction.save!
    process_transaction_async(transaction)
    transaction
  rescue ActiveRecord::RecordInvalid => e
    raise TransactionError, "Failed to create transaction: #{e.message}"
  end

  def self.calculate_balance(wallet)
    cache_key = "wallet_balance_#{wallet.id}"
    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      credits = wallet.wallet_transactions.credits.completed.sum(:amount_cents)
      debits = wallet.wallet_transactions.debits.completed.sum(:amount_cents)
      credits - debits
    end
    Balance.new(Rails.cache.read(cache_key))
  end

  def self.process_transaction(transaction)
    # Simulate processing logic; in real scenario, integrate with payment gateway
    transaction.update!(status: :completed, processed_at: Time.current)
    event = WalletTransactionEvent.from_transaction(transaction)
    # In a full Event Sourcing setup, persist the event to an event store
    Rails.logger.info("Transaction Event: #{event.to_h}")
    update_wallet_balance(transaction.mobile_wallet)
  rescue => e
    transaction.update!(status: :failed)
    raise TransactionError, "Processing failed: #{e.message}"
  end

  def self.reverse_transaction(transaction)
    return unless transaction.completed?

    reverse_tx = transaction.mobile_wallet.wallet_transactions.build(
      transaction_type: :refund,
      amount_cents: transaction.amount_cents,
      purpose: "Reversal of #{transaction.id}",
      status: :completed
    )
    reverse_tx.save!
    update_wallet_balance(transaction.mobile_wallet)
  end

  private

  def self.process_transaction_async(transaction)
    # Enqueue for asynchronous processing to ensure scalability
    WalletTransactionProcessorJob.perform_later(transaction.id)
  end

  def self.update_wallet_balance(wallet)
    new_balance = calculate_balance(wallet)
    wallet.update!(balance_cents: new_balance.cents)
  end
end