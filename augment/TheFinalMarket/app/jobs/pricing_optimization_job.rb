class PricingOptimizationJob < ApplicationJob
  queue_as :default
  
  # Run pricing optimization for all products with active dynamic pricing rules
  def perform(product_id = nil)
    if product_id
      optimize_product(Product.find(product_id))
    else
      optimize_all_products
    end
  end
  
  private
  
  def optimize_all_products
    # Get products with active dynamic pricing rules
    products_with_rules = Product.joins(:pricing_rules)
                                .where(pricing_rules: { status: :active, rule_type: :dynamic_ai })
                                .distinct
    
    products_with_rules.find_each do |product|
      optimize_product(product)
    end
  end
  
  def optimize_product(product)
    # Apply all applicable pricing rules
    service = DynamicPricingService.new(product)
    
    # Get optimal price
    optimal_price = service.optimal_price
    current_price = product.price_cents
    
    # Only update if price change is significant (> 2%)
    price_change_pct = ((optimal_price - current_price).to_f / current_price * 100).abs
    return if price_change_pct < 2
    
    # Update price
    product.update!(price_cents: optimal_price)
    
    # Create price change record
    product.price_changes.create!(
      old_price_cents: current_price,
      new_price_cents: optimal_price,
      pricing_rule: product.pricing_rules.find_by(rule_type: :dynamic_ai),
      reason: "Automated pricing optimization",
      metadata: {
        recommendation: service.price_recommendation,
        automated: true
      }
    )
    
    # Notify seller if significant change
    if price_change_pct > 10
      PricingNotificationMailer.significant_price_change(product, current_price, optimal_price).deliver_later
    end
  rescue => e
    Rails.logger.error "Failed to optimize pricing for product #{product.id}: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end

