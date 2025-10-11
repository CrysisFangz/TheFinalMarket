class PricingAnalyticsService
  def initialize(user_or_product = nil)
    @context = user_or_product
  end
  
  # Track price change for analytics
  def self.track_price_change(price_change)
    # Store metrics in Redis for real-time analytics
    redis = Redis.new
    date_key = Date.current.to_s
    
    # Increment counters
    redis.hincrby("price_changes:#{date_key}", 'total', 1)
    redis.hincrby("price_changes:#{date_key}", 'automated', 1) if price_change.automated?
    redis.hincrby("price_changes:#{date_key}", 'manual', 1) if price_change.manual?
    
    # Track price increase/decrease
    if price_change.price_increased?
      redis.hincrby("price_changes:#{date_key}", 'increases', 1)
    else
      redis.hincrby("price_changes:#{date_key}", 'decreases', 1)
    end
    
    # Set expiry (keep for 90 days)
    redis.expire("price_changes:#{date_key}", 90.days.to_i)
  end
  
  # Get pricing performance metrics
  def pricing_performance(period = 30.days)
    start_date = period.ago
    
    {
      total_price_changes: price_changes_count(start_date),
      automated_changes: automated_changes_count(start_date),
      manual_changes: manual_changes_count(start_date),
      average_change_percentage: average_change_percentage(start_date),
      revenue_impact: revenue_impact(start_date),
      conversion_impact: conversion_impact(start_date),
      top_performing_rules: top_performing_rules(start_date),
      price_optimization_score: price_optimization_score
    }
  end
  
  # Get price elasticity analysis
  def elasticity_analysis
    products = get_products
    
    products.map do |product|
      service = DynamicPricingService.new(product)
      {
        product_id: product.id,
        product_name: product.name,
        elasticity: service.price_elasticity,
        current_price: product.price_cents,
        optimal_price: service.optimal_price,
        potential_revenue_lift: calculate_revenue_lift(product, service)
      }
    end
  end
  
  # Get competitive pricing analysis
  def competitive_analysis
    products_with_competitors = Product.joins(
      "INNER JOIN competitor_prices ON competitor_prices.product_identifier = products.sku"
    ).distinct
    
    products_with_competitors.map do |product|
      competitor_prices = CompetitorPrice.for_product(product.sku).recent
      
      {
        product_id: product.id,
        product_name: product.name,
        our_price: product.price_cents,
        avg_competitor_price: competitor_prices.average(:price_cents)&.round,
        min_competitor_price: competitor_prices.minimum(:price_cents),
        max_competitor_price: competitor_prices.maximum(:price_cents),
        price_position: calculate_price_position(product, competitor_prices),
        recommendation: competitive_recommendation(product, competitor_prices)
      }
    end
  end
  
  # Get pricing trends over time
  def pricing_trends(days = 30)
    end_date = Date.current
    start_date = days.days.ago.to_date
    
    (start_date..end_date).map do |date|
      {
        date: date,
        avg_price: average_price_on_date(date),
        price_changes: price_changes_on_date(date),
        revenue: revenue_on_date(date),
        units_sold: units_sold_on_date(date)
      }
    end
  end
  
  # Get rule performance metrics
  def rule_performance_report
    PricingRule.active.map do |rule|
      changes = rule.price_changes.where('created_at > ?', 30.days.ago)
      
      {
        rule_id: rule.id,
        rule_name: rule.name,
        rule_type: rule.rule_type,
        times_applied: changes.count,
        avg_price_change: changes.average('new_price_cents - old_price_cents')&.round,
        total_revenue_impact: calculate_rule_revenue_impact(rule, changes),
        effectiveness_score: calculate_rule_effectiveness(rule, changes)
      }
    end.sort_by { |r| -r[:effectiveness_score] }
  end
  
  # Get A/B test results for pricing
  def pricing_ab_test_results
    # Analyze A/B tests related to pricing
    ab_tests = Split::Experiment.all.select { |e| e.name.include?('price') }
    
    ab_tests.map do |experiment|
      {
        name: experiment.name,
        variants: experiment.alternatives.map do |alt|
          {
            name: alt.name,
            participants: alt.participant_count,
            completed: alt.completed_count,
            conversion_rate: alt.conversion_rate,
            z_score: alt.z_score
          }
        end,
        winner: experiment.winner&.name,
        confidence: experiment.confidence_level
      }
    end
  end
  
  private
  
  def get_products
    if @context.is_a?(User)
      @context.products
    elsif @context.is_a?(Product)
      [@context]
    else
      Product.all
    end
  end
  
  def price_changes_count(start_date)
    PriceChange.where('created_at >= ?', start_date).count
  end
  
  def automated_changes_count(start_date)
    PriceChange.automated.where('created_at >= ?', start_date).count
  end
  
  def manual_changes_count(start_date)
    PriceChange.manual.where('created_at >= ?', start_date).count
  end
  
  def average_change_percentage(start_date)
    changes = PriceChange.where('created_at >= ?', start_date)
    return 0 if changes.empty?
    
    percentages = changes.map(&:price_change_percentage)
    (percentages.sum / percentages.size).round(2)
  end
  
  def revenue_impact(start_date)
    # Calculate revenue difference before/after price changes
    changes = PriceChange.where('created_at >= ?', start_date)
    
    total_impact = changes.sum do |change|
      product = change.product
      sales_after = product.line_items.where('created_at > ?', change.created_at).limit(10).sum(:price_cents)
      estimated_sales_before = sales_after / change.new_price_cents * change.old_price_cents
      sales_after - estimated_sales_before
    end
    
    total_impact.round
  end
  
  def conversion_impact(start_date)
    # Simplified conversion impact calculation
    changes = PriceChange.where('created_at >= ?', start_date)
    
    improvements = changes.count do |change|
      product = change.product
      views_before = product.product_views.where(created_at: (change.created_at - 7.days)..change.created_at).count
      views_after = product.product_views.where('created_at > ?', change.created_at).limit(views_before).count
      
      sales_before = product.line_items.where(created_at: (change.created_at - 7.days)..change.created_at).count
      sales_after = product.line_items.where('created_at > ?', change.created_at).limit(sales_before).count
      
      next false if views_before.zero? || views_after.zero?
      
      conv_before = sales_before.to_f / views_before
      conv_after = sales_after.to_f / views_after
      
      conv_after > conv_before
    end
    
    {
      improved: improvements,
      total: changes.count,
      improvement_rate: changes.count.zero? ? 0 : (improvements.to_f / changes.count * 100).round(2)
    }
  end
  
  def top_performing_rules(start_date)
    rule_performance_report.first(5)
  end
  
  def price_optimization_score
    # Calculate overall pricing optimization score (0-100)
    products = get_products
    return 0 if products.empty?
    
    scores = products.map do |product|
      service = DynamicPricingService.new(product)
      recommendation = service.price_recommendation
      
      # Score based on how close current price is to optimal
      diff_pct = (recommendation[:change_percentage].abs)
      100 - [diff_pct, 100].min
    end
    
    (scores.sum / scores.size).round
  end
  
  def calculate_revenue_lift(product, service)
    recommendation = service.price_recommendation
    expected_impact = recommendation[:expected_impact]
    
    current_weekly_revenue = product.line_items.where('created_at > ?', 7.days.ago).sum(:price_cents)
    expected_weekly_revenue = current_weekly_revenue * (1 + expected_impact[:revenue_change_percentage] / 100.0)
    
    ((expected_weekly_revenue - current_weekly_revenue) * 4).round # Monthly lift
  end
  
  def calculate_price_position(product, competitor_prices)
    return 'no_data' if competitor_prices.empty?
    
    avg_price = competitor_prices.average(:price_cents)
    our_price = product.price_cents
    
    diff_pct = ((our_price - avg_price) / avg_price * 100).round
    
    case diff_pct
    when -Float::INFINITY..-10 then 'low'
    when -10..10 then 'competitive'
    else 'high'
    end
  end
  
  def competitive_recommendation(product, competitor_prices)
    position = calculate_price_position(product, competitor_prices)
    
    case position
    when 'low'
      'Consider increasing price to improve margins'
    when 'high'
      'Consider decreasing price to be more competitive'
    else
      'Price is competitive'
    end
  end
  
  def average_price_on_date(date)
    Product.where('created_at <= ?', date.end_of_day).average(:price_cents)&.round || 0
  end
  
  def price_changes_on_date(date)
    PriceChange.where(created_at: date.beginning_of_day..date.end_of_day).count
  end
  
  def revenue_on_date(date)
    LineItem.where(created_at: date.beginning_of_day..date.end_of_day).sum(:price_cents)
  end
  
  def units_sold_on_date(date)
    LineItem.where(created_at: date.beginning_of_day..date.end_of_day).sum(:quantity)
  end
  
  def calculate_rule_revenue_impact(rule, changes)
    changes.sum do |change|
      product = change.product
      sales_after = product.line_items.where('created_at > ?', change.created_at).limit(10).sum(:price_cents)
      estimated_sales_before = sales_after / change.new_price_cents * change.old_price_cents
      sales_after - estimated_sales_before
    end.round
  end
  
  def calculate_rule_effectiveness(rule, changes)
    return 0 if changes.empty?
    
    # Score based on revenue impact and application frequency
    revenue_impact = calculate_rule_revenue_impact(rule, changes)
    application_frequency = changes.count
    
    # Normalize to 0-100 scale
    score = (revenue_impact / 1000.0) + (application_frequency * 2)
    [score, 100].min.round
  end
end

