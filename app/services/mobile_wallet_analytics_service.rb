class MobileWalletAnalyticsService
  attr_reader :mobile_wallet

  def initialize(mobile_wallet)
    @mobile_wallet = mobile_wallet
  end

  def balance
    Rails.logger.debug("Getting balance for MobileWallet ID: #{mobile_wallet.id}")
    mobile_wallet.balance_cents / 100.0
  end

  def transaction_history(limit: 50)
    Rails.logger.debug("Getting transaction history for MobileWallet ID: #{mobile_wallet.id}, limit: #{limit}")
    mobile_wallet.wallet_transactions.order(processed_at: :desc).limit(limit)
  end

  def summary
    Rails.logger.debug("Getting summary for MobileWallet ID: #{mobile_wallet.id}")
    {
      wallet_id: mobile_wallet.wallet_id,
      balance: balance,
      balance_cents: mobile_wallet.balance_cents,
      total_cards: mobile_wallet.wallet_cards.active.count,
      total_passes: mobile_wallet.wallet_passes.active.count,
      total_transactions: mobile_wallet.wallet_transactions.count,
      last_transaction: mobile_wallet.wallet_transactions.order(processed_at: :desc).first&.processed_at
    }
  end
end