# MultiCurrencyWalletLiquidityProviderService
# Handles liquidity provider operations
class MultiCurrencyWalletLiquidityProviderService
  def initialize(wallet)
    @wallet = wallet
  end

  def enable_liquidity_provider_status!(tier = :standard)
    @wallet.update!(
      liquidity_provider_status: tier,
      liquidity_provider_activated_at: Time.current,
      exchange_fee_waiver: calculate_liquidity_provider_discount(tier)
    )

    create_liquidity_pool_participations!(tier)
  end

  private

  def calculate_liquidity_provider_discount(tier)
    discount_rates = {
      standard: 0.1,
      premium: 0.25,
      vip: 0.5,
      institutional: 0.75
    }

    discount_rates[tier.to_sym] || 0.0
  end

  def create_liquidity_pool_participations!(tier)
    supported_currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY']

    supported_currencies.each do |currency_code|
      currency = Currency.find_by(code: currency_code)
      next unless currency

      @wallet.liquidity_pools.create!(
        currency: currency,
        participation_tier: tier,
        liquidity_provided_cents: calculate_initial_liquidity_amount(tier),
        participation_start_date: Time.current,
        status: :active,
        performance_metrics: {
          exchange_volume_24h_cents: 0,
          average_spread_bps: 0,
          uptime_percentage: 100.0
        }
      )
    end
  end

  def calculate_initial_liquidity_amount(tier)
    base_amounts = {
      standard: 10_000_00,
      premium: 100_000_00,
      vip: 1_000_000_00,
      institutional: 10_000_000_00
    }

    base_amounts[tier.to_sym] || 0
  end
end