# MultiCurrencyWalletFeeCalculationService
# Handles fee calculations and monetization
class MultiCurrencyWalletFeeCalculationService
  def initialize(wallet)
    @wallet = wallet
  end

  def calculate_exchange_fee(from_currency, to_currency, amount_cents)
    base_fee_cents = 100 # $1.00 base fee

    monthly_volume_cents = calculate_monthly_exchange_volume
    discount_rate = calculate_volume_discount_rate(monthly_volume_cents)

    lp_rebate_rate = liquidity_provider_rebate_rate

    promotional_discount = current_promotional_discount

    fee_cents = (base_fee_cents * (1 - discount_rate) * (1 - lp_rebate_rate) * (1 - promotional_discount)).round

    [fee_cents, 1].max
  end

  private

  def calculate_volume_discount_rate(monthly_volume_cents)
    discount_tiers = [
      { threshold_cents: 100_000_00, rate: 0.1 },
      { threshold_cents: 1_000_000_00, rate: 0.25 },
      { threshold_cents: 10_000_000_00, rate: 0.5 }
    ]

    applicable_tier = discount_tiers.reverse.find { |tier| monthly_volume_cents >= tier[:threshold_cents] }
    applicable_tier&.dig(:rate) || 0.0
  end

  def liquidity_provider_rebate_rate
    return 0.0 unless @wallet.liquidity_provider_status.present?

    lp_discount_rates = {
      'standard' => 0.1,
      'premium' => 0.25,
      'vip' => 0.5,
      'institutional' => 0.75
    }

    lp_discount_rates[@wallet.liquidity_provider_status] || 0.0
  end

  def current_promotional_discount
    @wallet.promotional_credits_cents > 0 ? 0.1 : 0.0
  end

  def calculate_monthly_exchange_volume
    Rails.cache.fetch("monthly_volume:#{@wallet.id}", expires_in: 1.hour) do
      @wallet.exchange_transactions.where('created_at >= ?', 1.month.ago).sum(:amount_cents)
    end
  end
end