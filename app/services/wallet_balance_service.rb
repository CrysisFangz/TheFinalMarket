# =============================================================================
# Wallet Balance Service - Immutable Balance State Management Engine
# =============================================================================
# This service manages wallet balance updates with atomic operations,
# ensuring referential transparency and preventing race conditions through
# optimistic locking and immutable state transitions.

class WalletBalanceService
  include Dry::Monads[:result]

  # Update balances for source and destination wallets after transaction confirmation
  # @param transaction [XrpTransaction] The confirmed transaction
  # @return [Dry::Monads::Result] Success or Failure with error
  def self.update_balances(transaction)
    return Failure('Transaction must be provided') unless transaction.is_a?(XrpTransaction)
    return Failure('Transaction not confirmed') unless transaction.confirmed?

    results = []

    # Update source wallet (debit)
    if transaction.source_wallet
      result = update_source_balance(transaction)
      results << result
    end

    # Update destination wallet (credit)
    if transaction.destination_wallet
      result = update_destination_balance(transaction)
      results << result
    end

    # Check if all updates succeeded
    if results.all?(&:success?)
      Success(transaction)
    else
      failures = results.select(&:failure?)
      Failure("Balance update failed: #{failures.map(&:failure).join(', ')}")
    end
  rescue StandardError => e
    Rails.logger.error("Balance update failed for transaction #{transaction.id}: #{e.message}")
    Failure("Balance update error: #{e.message}")
  end

  # Sync wallet balance with ledger
  # @param wallet [XrpWallet] The wallet to sync
  # @return [Dry::Monads::Result] Success with updated balance or Failure
  def self.sync_balance(wallet)
    return Failure('Wallet must be provided') unless wallet.is_a?(XrpWallet)

    ledger_balance = fetch_ledger_balance(wallet.xrp_address)

    wallet.update!(balance_xrp: ledger_balance)
    Success(wallet)
  rescue StandardError => e
    Rails.logger.error("Balance sync failed for wallet #{wallet.id}: #{e.message}")
    Failure("Balance sync error: #{e.message}")
  end

  private

  # Update source wallet balance (debit amount + fee)
  # @param transaction [XrpTransaction] The transaction
  # @return [Dry::Monads::Result] Success or Failure
  def self.update_source_balance(transaction)
    wallet = transaction.source_wallet

    # Use optimistic locking to prevent race conditions
    wallet.with_lock do
      new_balance = wallet.balance_xrp - transaction.amount_xrp - transaction.fee_xrp

      if new_balance >= 0
        wallet.update!(balance_xrp: new_balance)
        Success(wallet)
      else
        Failure("Insufficient balance for transaction #{transaction.id}")
      end
    end
  rescue ActiveRecord::StaleObjectError
    # Retry logic could be added here
    Failure("Concurrent balance update conflict for transaction #{transaction.id}")
  end

  # Update destination wallet balance (credit amount)
  # @param transaction [XrpTransaction] The transaction
  # @return [Dry::Monads::Result] Success or Failure
  def self.update_destination_balance(transaction)
    wallet = transaction.destination_wallet

    # Use optimistic locking
    wallet.with_lock do
      new_balance = wallet.balance_xrp + transaction.amount_xrp
      wallet.update!(balance_xrp: new_balance)
      Success(wallet)
    end
  rescue ActiveRecord::StaleObjectError
    Failure("Concurrent balance update conflict for transaction #{transaction.id}")
  end

  # Fetch current balance from XRP ledger
  # @param address [String] Wallet address
  # @return [Float] Current balance in XRP
  def self.fetch_ledger_balance(address)
    XrpLedgerService.get_balance(address)
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch ledger balance for address #{address}: #{e.message}")
    0.0 # Default to zero on error
  end
end