# MultiCurrencyWalletRepository
# Handles data access for MultiCurrencyWallet
class MultiCurrencyWalletRepository
  def self.find_active_wallets
    MultiCurrencyWallet.where(status: :active)
  end

  def self.find_high_liquidity_wallets
    MultiCurrencyWallet.where('total_balance_cents > ?', 100_000_00)
  end

  def self.find_global_commerce_enabled
    MultiCurrencyWallet.where(global_commerce_enabled: true)
  end

  def self.find_by_risk_level(level)
    MultiCurrencyWallet.where(risk_level: level)
  end

  def self.find_recently_active
    MultiCurrencyWallet.where('last_activity_at > ?', 30.days.ago)
  end

  def self.update_total_balance!(wallet)
    wallet.update!(total_balance_cents: calculate_total_balance_cents(wallet))
  end

  private

  def self.calculate_total_balance_cents(wallet)
    wallet.currency_balances.sum do |balance|
      (balance.balance_cents * balance.exchange_rate_at_balance).round
    end
  end
end