# MultiCurrencyWalletPortfolioManagementService
# Handles portfolio operations like rebalancing and snapshots
class MultiCurrencyWalletPortfolioManagementService
  def initialize(wallet)
    @wallet = wallet
  end

  def set_target_allocations!(allocations)
    total_percentage = allocations.values.sum
    unless total_percentage.between?(99.9, 100.1)
      raise ArgumentError, "Target allocations must sum to 100%, got #{total_percentage}%"
    end

    @wallet.update!(
      portfolio_preferences: @wallet.portfolio_preferences.merge({
        target_allocations: allocations,
        last_rebalancing_check: Time.current
      })
    )

    create_portfolio_snapshot!(:target_updated)
  end

  def execute_automatic_rebalancing!(force = false)
    return false unless @wallet.multi_currency_enabled? && auto_rebalancing_enabled?

    last_check = @wallet.portfolio_preferences.dig('last_rebalancing_check')
    rebalance_frequency = @wallet.portfolio_preferences.dig('rebalancing_frequency') || 'weekly'

    return false if !force && recently_rebalanced?(last_check, rebalance_frequency)

    current_allocations = calculate_current_allocations
    target_allocations = @wallet.portfolio_preferences.dig('target_allocations')

    return false unless target_allocations

    rebalancing_strategy = calculate_rebalancing_strategy(current_allocations, target_allocations)

    exchange_service = GlobalCurrencyExchangeService.new
    rebalancing_strategy[:exchanges].each do |exchange|
      exchange_service.execute_currency_exchange(
        exchange.merge(wallet_id: @wallet.id, user_id: @wallet.user_id),
        user_context
      )
    end

    @wallet.update!(
      portfolio_preferences: @wallet.portfolio_preferences.merge({
        last_rebalancing_check: Time.current,
        last_rebalancing_performance: rebalancing_strategy[:performance_impact]
      })
    )

    create_portfolio_snapshot!(:rebalanced)
    true
  end

  private

  def create_portfolio_snapshot!(snapshot_type = :regular)
    MultiCurrencyWalletPortfolioSnapshotJob.perform_later(@wallet.id, snapshot_type)
  end

  def calculate_current_allocations
    total_value_usd_cents = @wallet.total_balance_cents

    @wallet.currency_balances.each_with_object({}) do |balance, allocations|
      next if balance.balance_cents.zero?

      usd_value_cents = (balance.balance_cents * balance.exchange_rate_at_balance).round
      percentage = total_value_usd_cents.zero? ? 0 : (usd_value_cents.to_f / total_value_usd_cents * 100).round(2)

      allocations[balance.currency.code] = {
        balance_cents: balance.balance_cents,
        usd_value_cents: usd_value_cents,
        percentage: percentage,
        exchange_rate: balance.exchange_rate_at_balance
      }
    end
  end

  def calculate_rebalancing_strategy(current_allocations, target_allocations)
    strategy_calculator = PortfolioRebalancingStrategyCalculator.new(
      current_allocations: current_allocations,
      target_allocations: target_allocations,
      transaction_cost_model: :comprehensive_with_spread_impact,
      risk_management: :enabled_with_optimization,
      tax_considerations: :optimized_with_loss_harvesting
    )

    strategy_calculator.calculate do |calculator|
      calculator.analyze_allocation_variance
      calculator.evaluate_rebalancing_cost_benefit
      calculator.generate_optimal_exchange_sequence
      calculator.calculate_expected_performance_impact
      calculator.validate_strategy_feasibility
    end
  end

  def calculate_portfolio_health_score(allocations)
    diversification_score = calculate_diversification_score(allocations)
    risk_score = calculate_risk_score(allocations)
    liquidity_score = calculate_liquidity_score(allocations)

    (diversification_score * 0.4 + risk_score * 0.3 + liquidity_score * 0.3).round(1)
  end

  def calculate_diversification_score(allocations)
    percentages = allocations.values.map { |a| a[:percentage] }
    return 0 if percentages.empty?

    hhi = percentages.sum { |p| (p / 100.0) ** 2 }
    [(1 - hhi) * 100, 100].min.round(1)
  end

  def calculate_risk_score(allocations)
    risk_weights = {
      'USD' => 0.1, 'EUR' => 0.2, 'GBP' => 0.3, 'JPY' => 0.4,
      'CAD' => 0.25, 'AUD' => 0.35, 'CHF' => 0.15, 'CNY' => 0.4
    }

    weighted_risk = allocations.sum do |code, allocation|
      weight = risk_weights[code] || 0.3
      allocation[:percentage] / 100.0 * weight * 100
    end

    [weighted_risk, 100].min.round(1)
  end

  def calculate_liquidity_score(allocations)
    liquidity_weights = {
      'USD' => 1.0, 'EUR' => 0.9, 'GBP' => 0.85, 'JPY' => 0.8,
      'CAD' => 0.75, 'AUD' => 0.7, 'CHF' => 0.9, 'CNY' => 0.6
    }

    weighted_liquidity = allocations.sum do |code, allocation|
      weight = liquidity_weights[code] || 0.5
      allocation[:percentage] / 100.0 * weight * 100
    end

    weighted_liquidity.round(1)
  end

  def current_exchange_rates
    @wallet.currency_balances.each_with_object({}) do |balance, rates|
      rates[balance.currency.code] = balance.exchange_rate_at_balance
    end
  end

  def current_market_context
    {
      volatility_index: current_market_volatility,
      liquidity_score: current_liquidity_score,
      exchange_rate_trends: current_exchange_rate_trends,
      timestamp: Time.current
    }
  end

  def current_market_volatility
    0.15 # Placeholder
  end

  def current_liquidity_score
    0.85 # Placeholder
  end

  def current_exchange_rate_trends
    {} # Placeholder
  end

  def recently_rebalanced?(last_check, frequency)
    return false unless last_check

    threshold_time = case frequency.to_s
                     when 'daily' then 1.day.ago
                     when 'weekly' then 1.week.ago
                     when 'monthly' then 1.month.ago
                     else 1.week.ago
                     end

    last_check > threshold_time
  end

  def auto_rebalancing_enabled?
    @wallet.portfolio_preferences.dig('auto_exchange_enabled') == true
  end

  def user_context
    {
      user_id: @wallet.user_id,
      wallet_id: @wallet.id,
      wallet_type: @wallet.wallet_type,
      global_commerce_enabled: @wallet.global_commerce_enabled?,
      liquidity_provider_status: @wallet.liquidity_provider_status,
      risk_level: @wallet.risk_level,
      fee_structure: @wallet.fee_structure
    }
  end
end