class MobileWalletTransactionService
  attr_reader :mobile_wallet

  def initialize(mobile_wallet)
    @mobile_wallet = mobile_wallet
  end

  def add_funds(amount_cents, source, metadata = {})
    Rails.logger.info("Adding funds #{amount_cents} cents to MobileWallet ID: #{mobile_wallet.id}")
    return false unless mobile_wallet.active?

    transaction = mobile_wallet.wallet_transactions.create!(
      transaction_type: :credit,
      amount_cents: amount_cents,
      source: source,
      balance_after_cents: mobile_wallet.balance_cents + amount_cents,
      transaction_data: metadata,
      processed_at: Time.current
    )

    mobile_wallet.increment!(:balance_cents, amount_cents)
    Rails.logger.info("Funds added successfully to MobileWallet ID: #{mobile_wallet.id}")
    transaction
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error adding funds to MobileWallet ID: #{mobile_wallet.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error adding funds to MobileWallet ID: #{mobile_wallet.id} - #{e.message}")
    raise
  end

  def deduct_funds(amount_cents, purpose, metadata = {})
    Rails.logger.info("Deducting funds #{amount_cents} cents from MobileWallet ID: #{mobile_wallet.id}")
    return false unless mobile_wallet.active?
    return false if mobile_wallet.balance_cents < amount_cents

    transaction = mobile_wallet.wallet_transactions.create!(
      transaction_type: :debit,
      amount_cents: amount_cents,
      purpose: purpose,
      balance_after_cents: mobile_wallet.balance_cents - amount_cents,
      transaction_data: metadata,
      processed_at: Time.current
    )

    mobile_wallet.decrement!(:balance_cents, amount_cents)
    Rails.logger.info("Funds deducted successfully from MobileWallet ID: #{mobile_wallet.id}")
    transaction
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error deducting funds from MobileWallet ID: #{mobile_wallet.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error deducting funds from MobileWallet ID: #{mobile_wallet.id} - #{e.message}")
    raise
  end
end