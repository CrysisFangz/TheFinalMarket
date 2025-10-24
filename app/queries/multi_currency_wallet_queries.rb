# MultiCurrencyWalletQueries
# Query objects for CQRS pattern
class MultiCurrencyWalletQueries
  def self.active_wallets
    MultiCurrencyWallet.active_wallets
  end

  def self.high_liquidity_wallets
    MultiCurrencyWallet.high_liquidity
  end

  def self.global_commerce_enabled_wallets
    MultiCurrencyWallet.global_commerce_enabled
  end

  def self.wallets_by_risk_level(level)
    MultiCurrencyWallet.by_risk_level(level)
  end

  def self.recently_active_wallets
    MultiCurrencyWallet.recently_active
  end

  def self.wallet_with_balances(wallet_id)
    MultiCurrencyWallet.includes(:currency_balances).find(wallet_id)
  end

  def self.wallet_portfolio_summary(wallet_id)
    wallet = MultiCurrencyWallet.find(wallet_id)
    {
      total_balance_cents: wallet.total_balance_cents,
      currency_allocations: wallet.currency_balances.map do |balance|
        {
          currency_code: balance.currency.code,
          balance_cents: balance.balance_cents,
          usd_equivalent_cents: (balance.balance_cents * balance.exchange_rate_at_balance).round
        }
      end
    }
  end
end