# MultiCurrencyWalletPortfolioHealthCalculator
# Calculates portfolio health scores
class MultiCurrencyWalletPortfolioHealthCalculator
  def initialize(allocations)
    @allocations = allocations
  end

  def calculate
    diversification_score = calculate_diversification_score
    risk_score = calculate_risk_score
    liquidity_score = calculate_liquidity_score

    (diversification_score * 0.4 + risk_score * 0.3 + liquidity_score * 0.3).round(1)
  end

  private

  def calculate_diversification_score
    percentages = @allocations.values.map { |a| a[:percentage] }
    return 0 if percentages.empty?

    hhi = percentages.sum { |p| (p / 100.0) ** 2 }
    [(1 - hhi) * 100, 100].min.round(1)
  end

  def calculate_risk_score
    risk_weights = {
      'USD' => 0.1, 'EUR' => 0.2, 'GBP' => 0.3, 'JPY' => 0.4,
      'CAD' => 0.25, 'AUD' => 0.35, 'CHF' => 0.15, 'CNY' => 0.4
    }

    weighted_risk = @allocations.sum do |code, allocation|
      weight = risk_weights[code] || 0.3
      allocation[:percentage] / 100.0 * weight * 100
    end

    [weighted_risk, 100].min.round(1)
  end

  def calculate_liquidity_score
    liquidity_weights = {
      'USD' => 1.0, 'EUR' => 0.9, 'GBP' => 0.85, 'JPY' => 0.8,
      'CAD' => 0.75, 'AUD' => 0.7, 'CHF' => 0.9, 'CNY' => 0.6
    }

    weighted_liquidity = @allocations.sum do |code, allocation|
      weight = liquidity_weights[code] || 0.5
      allocation[:percentage] / 100.0 * weight * 100
    end

    weighted_liquidity.round(1)
  end
end