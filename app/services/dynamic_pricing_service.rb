class DynamicPricingService
  attr_reader :product
  
  def initialize(product)
    @product = product
  end
  
  # Calculate optimal price using ML/AI
  def optimal_price
    Rails.cache.fetch("optimal_price:#{product.id}", expires_in: 1.hour) do
      calculate_optimal_price
    end
  end
  
  # Get price recommendation with reasoning
  def price_recommendation
    {
      current_price: product.price_cents,
      recommended_price: optimal_price,
      change_percentage: price_change_percentage,
      confidence: confidence_score,
      reasoning: recommendation_reasoning,
      expected_impact: expected_impact,
      factors: pricing_factors
    }
  end
  
  # Apply all applicable pricing rules
  def apply_pricing_rules(context = {})
    applicable_rules = PricingRule.active
                                  .for_product(product)
                                  .by_priority
                                  .select { |rule| rule.applicable?(context) }
    
    return product.price_cents if applicable_rules.empty?
    
    # Apply highest priority rule
    highest_priority_rule = applicable_rules.first
    highest_priority_rule.calculate_price(product.price_cents, context)
  end
  
  # Calculate price elasticity
  def price_elasticity
    calculate_price_elasticity
  end
  
  # Get pricing insights
  def pricing_insights
    {
      elasticity: price_elasticity,
      demand_trend: demand_trend,
      competitor_position: competitor_position,
      optimal_price_range: optimal_price_range,
      revenue_projection: revenue_projection,
      margin_analysis: margin_analysis
    }
  end
  
  private
  
  def calculate_optimal_price
    base_price = product.price_cents
    
    # Gather all pricing factors
    factors = {
      demand_factor: demand_adjustment_factor,
      competition_factor: competition_adjustment_factor,
      inventory_factor: inventory_adjustment_factor,
      seasonality_factor: seasonality_adjustment_factor,
      historical_factor: historical_performance_factor
    }
    
    # Calculate weighted price
    weighted_price = base_price
    
    factors.each do |factor_name, factor_value|
      weighted_price *= factor_value
    end
    
    # Apply constraints
    apply_price_constraints(weighted_price.round)
  end
  
  def demand_adjustment_factor
    # Analyze recent demand
    views_last_7d = product.product_views.where('created_at > ?', 7.days.ago).count
    sales_last_7d = product.line_items.where('created_at > ?', 7.days.ago).count
    
    # Calculate demand score (0.8 to 1.2 range)
    demand_score = (views_last_7d * 0.01) + (sales_last_7d * 0.5)
    
    case demand_score
    when 0..5
      0.90  # Low demand - decrease price 10%
    when 5..15
      0.95  # Below average - decrease price 5%
    when 15..30
      1.00  # Average - no change
    when 30..50
      1.05  # Above average - increase price 5%
    else
      1.10  # High demand - increase price 10%
    end
  end
  
  def competition_adjustment_factor
    competitor_prices = CompetitorPrice.active
                                      .for_product(product.sku)
                                      .recent
                                      .pluck(:price_cents)
    
    return 1.0 if competitor_prices.empty?
    
    avg_competitor_price = competitor_prices.sum / competitor_prices.size
    current_price = product.price_cents
    
    # Adjust based on competitive position
    if current_price > avg_competitor_price * 1.1
      0.95  # We're too expensive - decrease
    elsif current_price < avg_competitor_price * 0.9
      1.05  # We're too cheap - increase
    else
      1.0   # Competitive - no change
    end
  end
  
  def inventory_adjustment_factor
    stock = product.stock_quantity || 0
    
    case stock
    when 0
      1.0   # Out of stock - no change (can't sell anyway)
    when 1..5
      0.85  # Very low stock - clearance pricing
    when 6..20
      0.95  # Low stock - slight discount
    when 21..50
      1.0   # Normal stock - no change
    else
      1.02  # High stock - slight increase (we have plenty)
    end
  end
  
  def seasonality_adjustment_factor
    # Simple seasonality based on month
    month = Date.current.month
    
    # Adjust based on typical shopping patterns
    case month
    when 11, 12  # Holiday season
      1.05
    when 1       # Post-holiday
      0.90
    when 7, 8    # Summer
      0.95
    else
      1.0
    end
  end
  
  def historical_performance_factor
    # Analyze conversion rate at current price
    views = product.product_views.where('created_at > ?', 30.days.ago).count
    sales = product.line_items.where('created_at > ?', 30.days.ago).count
    
    return 1.0 if views.zero?
    
    conversion_rate = (sales.to_f / views * 100)
    
    # Adjust based on conversion performance
    case conversion_rate
    when 0..1
      0.90  # Very low conversion - price too high
    when 1..3
      0.95  # Low conversion - slight decrease
    when 3..7
      1.0   # Good conversion - no change
    when 7..15
      1.05  # Great conversion - can increase
    else
      1.10  # Excellent conversion - definitely increase
    end
  end
  
  def apply_price_constraints(price)
    # Get product's cost to ensure profitability
    min_price = (product.cost_cents || 0) * 1.2  # Minimum 20% margin
    max_price = product.price_cents * 1.5        # Max 50% increase from current
    
    [[price, min_price].max, max_price].min
  end
  
  def price_change_percentage
    return 0 if product.price_cents.zero?
    ((optimal_price - product.price_cents).to_f / product.price_cents * 100).round(2)
  end
  
  def confidence_score
    # Calculate confidence based on data availability
    factors = [
      product.product_views.where('created_at > ?', 30.days.ago).count > 50,
      product.line_items.where('created_at > ?', 30.days.ago).count > 5,
      CompetitorPrice.for_product(product.sku).recent.count > 2,
      product.created_at < 30.days.ago
    ]
    
    (factors.count(true).to_f / factors.size * 100).round
  end
  
  def recommendation_reasoning
    reasons = []
    
    if demand_adjustment_factor > 1.0
      reasons << "High demand detected - price increase recommended"
    elsif demand_adjustment_factor < 1.0
      reasons << "Low demand - price decrease to stimulate sales"
    end
    
    if competition_adjustment_factor < 1.0
      reasons << "Price above market average - adjustment needed"
    elsif competition_adjustment_factor > 1.0
      reasons << "Price below market - opportunity to increase"
    end
    
    if inventory_adjustment_factor < 1.0
      reasons << "Low inventory - clearance pricing suggested"
    end
    
    reasons.join(". ")
  end
  
  def expected_impact
    price_change = price_change_percentage
    
    # Estimate impact on sales and revenue
    elasticity = price_elasticity
    expected_volume_change = -elasticity * price_change
    expected_revenue_change = price_change + expected_volume_change
    
    {
      volume_change_percentage: expected_volume_change.round(2),
      revenue_change_percentage: expected_revenue_change.round(2),
      estimated_units_per_week: estimate_weekly_units(expected_volume_change),
      estimated_revenue_per_week: estimate_weekly_revenue(expected_revenue_change)
    }
  end
  
  def pricing_factors
    {
      demand: {
        factor: demand_adjustment_factor,
        description: demand_description
      },
      competition: {
        factor: competition_adjustment_factor,
        description: competition_description
      },
      inventory: {
        factor: inventory_adjustment_factor,
        description: inventory_description
      },
      seasonality: {
        factor: seasonality_adjustment_factor,
        description: seasonality_description
      },
      historical: {
        factor: historical_performance_factor,
        description: historical_description
      }
    }
  end
  
  def calculate_price_elasticity
    # Simplified elasticity calculation
    # In production, this would use historical price/volume data
    
    price_changes = product.price_changes.order(created_at: :desc).limit(10)
    return 1.0 if price_changes.count < 2
    
    # Calculate average elasticity from historical data
    elasticities = []
    
    price_changes.each_cons(2) do |newer, older|
      price_change_pct = ((newer.new_price_cents - older.new_price_cents).to_f / older.new_price_cents * 100)
      next if price_change_pct.zero?
      
      # Get sales volume change
      newer_sales = product.line_items.where(created_at: newer.created_at..(newer.created_at + 7.days)).count
      older_sales = product.line_items.where(created_at: older.created_at..(older.created_at + 7.days)).count
      
      next if older_sales.zero?
      
      volume_change_pct = ((newer_sales - older_sales).to_f / older_sales * 100)
      elasticity = volume_change_pct / price_change_pct
      elasticities << elasticity.abs
    end
    
    elasticities.empty? ? 1.0 : (elasticities.sum / elasticities.size).round(2)
  end
  
  def demand_trend
    views_this_week = product.product_views.where('created_at > ?', 7.days.ago).count
    views_last_week = product.product_views.where('created_at BETWEEN ? AND ?', 14.days.ago, 7.days.ago).count
    
    return 'stable' if views_last_week.zero?
    
    change = ((views_this_week - views_last_week).to_f / views_last_week * 100).round
    
    case change
    when -Float::INFINITY..-20 then 'declining_fast'
    when -20..-10 then 'declining'
    when -10..10 then 'stable'
    when 10..20 then 'growing'
    else 'growing_fast'
    end
  end
  
  def competitor_position
    competitor_prices = CompetitorPrice.for_product(product.sku).recent.pluck(:price_cents)
    return 'no_data' if competitor_prices.empty?
    
    avg_price = competitor_prices.sum / competitor_prices.size
    current_price = product.price_cents
    
    diff_pct = ((current_price - avg_price).to_f / avg_price * 100).round
    
    case diff_pct
    when -Float::INFINITY..-15 then 'significantly_lower'
    when -15..-5 then 'lower'
    when -5..5 then 'competitive'
    when 5..15 then 'higher'
    else 'significantly_higher'
    end
  end
  
  def optimal_price_range
    optimal = optimal_price
    variance = optimal * 0.1  # 10% variance
    
    {
      min: (optimal - variance).round,
      optimal: optimal,
      max: (optimal + variance).round
    }
  end
  
  def revenue_projection
    # Project revenue for next 30 days at different price points
    current_weekly_sales = product.line_items.where('created_at > ?', 7.days.ago).count
    
    {
      current_price: {
        price: product.price_cents,
        estimated_units: current_weekly_sales * 4,
        estimated_revenue: product.price_cents * current_weekly_sales * 4
      },
      optimal_price: {
        price: optimal_price,
        estimated_units: estimate_weekly_units(price_change_percentage) * 4,
        estimated_revenue: estimate_weekly_revenue(price_change_percentage) * 4
      }
    }
  end
  
  def margin_analysis
    cost = product.cost_cents || 0
    current_margin = product.price_cents - cost
    optimal_margin = optimal_price - cost
    
    {
      current: {
        margin_cents: current_margin,
        margin_percentage: cost.zero? ? 0 : (current_margin.to_f / product.price_cents * 100).round(2)
      },
      optimal: {
        margin_cents: optimal_margin,
        margin_percentage: cost.zero? ? 0 : (optimal_margin.to_f / optimal_price * 100).round(2)
      }
    }
  end
  
  def estimate_weekly_units(volume_change_pct)
    current_weekly = product.line_items.where('created_at > ?', 7.days.ago).count
    (current_weekly * (1 + volume_change_pct / 100.0)).round
  end
  
  def estimate_weekly_revenue(revenue_change_pct)
    current_weekly_revenue = product.line_items.where('created_at > ?', 7.days.ago).sum(:price_cents)
    (current_weekly_revenue * (1 + revenue_change_pct / 100.0)).round
  end
  
  # Helper methods for factor descriptions
  def demand_description
    "Based on #{product.product_views.where('created_at > ?', 7.days.ago).count} views and #{product.line_items.where('created_at > ?', 7.days.ago).count} sales in last 7 days"
  end
  
  def competition_description
    count = CompetitorPrice.for_product(product.sku).recent.count
    "Based on #{count} competitor price#{count == 1 ? '' : 's'}"
  end
  
  def inventory_description
    "Current stock: #{product.stock_quantity || 0} units"
  end
  
  def seasonality_description
    "#{Date::MONTHNAMES[Date.current.month]} seasonal adjustment"
  end
  
  def historical_description
    views = product.product_views.where('created_at > ?', 30.days.ago).count
    sales = product.line_items.where('created_at > ?', 30.days.ago).count
    conversion = views.zero? ? 0 : (sales.to_f / views * 100).round(2)
    "#{conversion}% conversion rate over last 30 days"
  end
end

