puts "🎯 Seeding Dynamic Pricing System..."

# Get some products to work with
products = Product.limit(20)

if products.empty?
  puts "⚠️  No products found. Please seed products first."
  return
end

# Create pricing rules for products
puts "Creating pricing rules..."

products.each_with_index do |product, index|
  # Add cost to products (for margin calculations)
  product.update!(
    cost_cents: (product.price_cents * 0.6).to_i, # 40% margin
    auto_pricing_enabled: index.even? # Enable auto-pricing for half the products
  )
  
  # Create different types of pricing rules
  case index % 5
  when 0
    # Flash Sale Rule
    product.pricing_rules.create!(
      user: product.user,
      name: "Weekend Flash Sale",
      description: "30% off during weekends",
      rule_type: :time_based,
      status: :active,
      priority: :high,
      min_price_cents: (product.price_cents * 0.5).to_i,
      max_price_cents: product.price_cents,
      config: {
        flash_sale_active: true,
        flash_sale_discount: 30,
        happy_hours: [14, 15, 16] # 2-4 PM
      }
    )
    
  when 1
    # Inventory-Based Clearance
    product.pricing_rules.create!(
      user: product.user,
      name: "Low Stock Clearance",
      description: "Automatic discount when stock is low",
      rule_type: :inventory_based,
      status: :active,
      priority: :medium,
      min_price_cents: (product.price_cents * 0.6).to_i,
      config: {
        low_stock_threshold: 10,
        clearance_discount: 25
      }
    )
    
  when 2
    # Demand-Based Surge Pricing
    product.pricing_rules.create!(
      user: product.user,
      name: "Surge Pricing",
      description: "Increase price during high demand",
      rule_type: :demand_based,
      status: :active,
      priority: :high,
      max_price_cents: (product.price_cents * 1.3).to_i,
      config: {
        high_demand_threshold: 50,
        surge_percentage: 15,
        low_demand_threshold: 5,
        low_demand_discount: 10
      }
    )
    
  when 3
    # Competitor-Based Price Matching
    product.pricing_rules.create!(
      user: product.user,
      name: "Competitive Pricing",
      description: "Match competitor prices",
      rule_type: :competitor_based,
      status: :active,
      priority: :critical,
      min_price_cents: (product.price_cents * 0.7).to_i,
      max_price_cents: (product.price_cents * 1.2).to_i,
      config: {
        competitor_strategy: 'undercut',
        undercut_percentage: 5
      }
    )
    
  when 4
    # AI-Optimized Dynamic Pricing
    product.pricing_rules.create!(
      user: product.user,
      name: "AI Price Optimization",
      description: "Automatically optimize price using AI",
      rule_type: :dynamic_ai,
      status: :active,
      priority: :critical,
      min_price_cents: (product.price_cents * 0.8).to_i,
      max_price_cents: (product.price_cents * 1.2).to_i,
      config: {}
    )
  end
  
  # Add volume discount rule to some products
  if index % 3 == 0
    product.pricing_rules.create!(
      user: product.user,
      name: "Volume Discount",
      description: "Bulk purchase discounts",
      rule_type: :volume,
      status: :active,
      priority: :low,
      config: {
        volume_tiers: [
          { 'min' => 10, 'discount' => 5 },
          { 'min' => 50, 'discount' => 10 },
          { 'min' => 100, 'discount' => 15 }
        ]
      }
    )
  end
end

puts "✅ Created #{PricingRule.count} pricing rules"

# Create some competitor prices
puts "Creating competitor prices..."

competitor_names = ['Amazon', 'eBay', 'Walmart', 'Target', 'Best Buy']

products.first(10).each do |product|
  next unless product.sku.present?
  
  # Create 2-3 competitor prices per product
  rand(2..3).times do
    competitor_name = competitor_names.sample
    
    # Price varies from 90% to 110% of our price
    competitor_price = (product.price_cents * (0.9 + rand * 0.2)).to_i
    
    CompetitorPrice.create!(
      competitor_name: competitor_name,
      product_identifier: product.sku,
      price_cents: competitor_price,
      previous_price_cents: (competitor_price * 1.05).to_i,
      url: "https://#{competitor_name.downcase}.com/product/#{product.sku}",
      in_stock: [true, true, true, false].sample, # 75% in stock
      active: true,
      last_checked_at: rand(1..24).hours.ago
    )
  end
end

puts "✅ Created #{CompetitorPrice.count} competitor prices"

# Create some price change history
puts "Creating price change history..."

products.first(15).each do |product|
  # Create 3-5 historical price changes
  rand(3..5).times do |i|
    days_ago = (i + 1) * 7 # Weekly changes
    old_price = (product.price_cents * (0.9 + rand * 0.2)).to_i
    new_price = (product.price_cents * (0.9 + rand * 0.2)).to_i
    
    pricing_rule = product.pricing_rules.sample
    
    PriceChange.create!(
      product: product,
      pricing_rule: pricing_rule,
      old_price_cents: old_price,
      new_price_cents: new_price,
      reason: pricing_rule ? "Applied rule: #{pricing_rule.name}" : "Manual adjustment",
      metadata: {
        automated: pricing_rule.present?,
        change_percentage: ((new_price - old_price).to_f / old_price * 100).round(2)
      },
      created_at: days_ago.days.ago
    )
  end
end

puts "✅ Created #{PriceChange.count} price change records"

# Create a price experiment
puts "Creating price experiments..."

products.first(5).each do |product|
  PriceExperiment.create!(
    product: product,
    user: product.user,
    name: "Price Test: #{product.name}",
    description: "Testing optimal price point",
    status: :active,
    control_price_cents: product.price_cents,
    variant_price_cents: (product.price_cents * 0.9).to_i, # 10% discount
    control_views: rand(100..500),
    control_conversions: rand(10..50),
    variant_views: rand(100..500),
    variant_conversions: rand(10..50),
    started_at: 7.days.ago,
    metadata: {
      hypothesis: "Lower price will increase conversion rate",
      target_metric: "conversion_rate"
    }
  )
end

puts "✅ Created #{PriceExperiment.count} price experiments"

# Add pricing rule conditions to some rules
puts "Adding pricing rule conditions..."

PricingRule.where(rule_type: :time_based).each do |rule|
  # Only apply on weekends
  rule.pricing_rule_conditions.create!(
    condition_type: :day_of_week,
    operator: :in_list,
    value: '0,6' # Sunday and Saturday
  )
end

PricingRule.where(rule_type: :inventory_based).each do |rule|
  # Only when stock is below 10
  rule.pricing_rule_conditions.create!(
    condition_type: :stock_level,
    operator: :less_than,
    value: '10'
  )
end

PricingRule.where(rule_type: :demand_based).each do |rule|
  # Only when views are high
  rule.pricing_rule_conditions.create!(
    condition_type: :view_count,
    operator: :greater_than,
    value: '50'
  )
end

puts "✅ Created #{PricingRuleCondition.count} pricing rule conditions"

puts ""
puts "🎉 Dynamic Pricing System seeded successfully!"
puts ""
puts "Summary:"
puts "  - #{PricingRule.count} pricing rules"
puts "  - #{CompetitorPrice.count} competitor prices"
puts "  - #{PriceChange.count} price changes"
puts "  - #{PriceExperiment.count} price experiments"
puts "  - #{PricingRuleCondition.count} rule conditions"
puts ""
puts "Next steps:"
puts "  1. Visit /seller/pricing to see the pricing dashboard"
puts "  2. Schedule PricingOptimizationJob to run hourly"
puts "  3. Schedule CompetitorPriceScraperJob to run daily"
puts ""

