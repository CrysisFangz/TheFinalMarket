class PricingRule < ApplicationRecord
  belongs_to :product
  belongs_to :user
  
  has_many :price_changes, dependent: :destroy
  has_many :pricing_rule_conditions, dependent: :destroy
  
  # Rule types
  enum rule_type: {
    time_based: 0,        # Flash sales, happy hours
    inventory_based: 1,   # Clearance pricing
    demand_based: 2,      # Surge pricing
    competitor_based: 3,  # Price matching
    seasonal: 4,          # Holiday pricing
    bundle: 5,            # Bundle discounts
    volume: 6,            # Bulk discounts
    dynamic_ai: 7         # AI-optimized pricing
  }
  
  # Status
  enum status: {
    draft: 0,
    active: 1,
    paused: 2,
    expired: 3,
    archived: 4
  }
  
  # Priority levels (higher number = higher priority)
  enum priority: {
    low: 0,
    medium: 1,
    high: 2,
    critical: 3
  }
  
  validates :name, presence: true
  validates :rule_type, presence: true
  validates :min_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :priority, presence: true
  
  validate :validate_price_bounds
  validate :validate_date_range
  
  scope :active, -> { where(status: :active) }
  scope :for_product, ->(product) { where(product: product) }
  scope :by_priority, -> { order(priority: :desc, created_at: :desc) }
  scope :current, -> { where('start_date <= ? AND (end_date IS NULL OR end_date >= ?)', Date.current, Date.current) }
  
  # Calculate price based on this rule
  def calculate_price(base_price, context = {})
    return base_price unless active? && applicable?(context)
    
    new_price = case rule_type.to_sym
    when :time_based
      calculate_time_based_price(base_price, context)
    when :inventory_based
      calculate_inventory_based_price(base_price, context)
    when :demand_based
      calculate_demand_based_price(base_price, context)
    when :competitor_based
      calculate_competitor_based_price(base_price, context)
    when :seasonal
      calculate_seasonal_price(base_price, context)
    when :bundle
      calculate_bundle_price(base_price, context)
    when :volume
      calculate_volume_price(base_price, context)
    when :dynamic_ai
      calculate_ai_optimized_price(base_price, context)
    else
      base_price
    end
    
    # Apply min/max constraints
    apply_price_bounds(new_price)
  end
  
  # Check if rule is applicable in current context
  def applicable?(context = {})
    return false unless active?
    return false if start_date && start_date > Date.current
    return false if end_date && end_date < Date.current
    
    # Check all conditions
    pricing_rule_conditions.all? { |condition| condition.met?(context) }
  end
  
  # Apply the rule and create price change record
  def apply!(context = {})
    return unless applicable?(context)
    
    old_price = product.price_cents
    new_price = calculate_price(old_price, context)
    
    if old_price != new_price
      price_changes.create!(
        product: product,
        old_price_cents: old_price,
        new_price_cents: new_price,
        reason: "Applied rule: #{name}",
        metadata: context.merge(rule_type: rule_type)
      )
      
      product.update!(price_cents: new_price)
    end
  end
  
  private
  
  def calculate_time_based_price(base_price, context)
    current_hour = Time.current.hour
    
    # Happy hour pricing (e.g., 20% off between 2-4 PM)
    if config['happy_hours']&.include?(current_hour)
      discount_percentage = config['happy_hour_discount'] || 20
      base_price * (1 - discount_percentage / 100.0)
    # Flash sale
    elsif config['flash_sale_active']
      base_price * (1 - (config['flash_sale_discount'] || 30) / 100.0)
    else
      base_price
    end
  end
  
  def calculate_inventory_based_price(base_price, context)
    stock_level = product.stock_quantity || 0
    low_stock_threshold = config['low_stock_threshold'] || 10
    
    if stock_level <= low_stock_threshold && stock_level > 0
      # Clearance pricing - increase discount as stock decreases
      discount_percentage = config['clearance_discount'] || 25
      discount_percentage += (low_stock_threshold - stock_level) * 2 # Additional 2% per unit
      base_price * (1 - [discount_percentage, 50].min / 100.0) # Max 50% off
    elsif stock_level == 0
      base_price # No discount if out of stock
    else
      base_price
    end
  end
  
  def calculate_demand_based_price(base_price, context)
    # Get recent view count and purchase velocity
    views_last_24h = product.product_views.where('created_at > ?', 24.hours.ago).count
    purchases_last_24h = product.line_items.where('created_at > ?', 24.hours.ago).count
    
    demand_score = (views_last_24h * 0.1) + (purchases_last_24h * 10)
    
    # High demand = price increase (surge pricing)
    if demand_score > (config['high_demand_threshold'] || 50)
      surge_percentage = config['surge_percentage'] || 15
      base_price * (1 + surge_percentage / 100.0)
    # Low demand = price decrease
    elsif demand_score < (config['low_demand_threshold'] || 5)
      discount_percentage = config['low_demand_discount'] || 10
      base_price * (1 - discount_percentage / 100.0)
    else
      base_price
    end
  end
  
  def calculate_competitor_based_price(base_price, context)
    # Get competitor prices
    competitor_prices = CompetitorPrice.active
                                      .where(product_identifier: product.sku)
                                      .where('updated_at > ?', 24.hours.ago)
                                      .pluck(:price_cents)
    
    return base_price if competitor_prices.empty?
    
    avg_competitor_price = competitor_prices.sum / competitor_prices.size
    min_competitor_price = competitor_prices.min
    
    strategy = config['competitor_strategy'] || 'match_lowest'
    
    case strategy
    when 'match_lowest'
      # Match the lowest competitor price
      [min_competitor_price, base_price].min
    when 'undercut'
      # Undercut by percentage
      undercut_percentage = config['undercut_percentage'] || 5
      min_competitor_price * (1 - undercut_percentage / 100.0)
    when 'match_average'
      # Match average competitor price
      avg_competitor_price
    when 'premium'
      # Stay above average by percentage
      premium_percentage = config['premium_percentage'] || 10
      avg_competitor_price * (1 + premium_percentage / 100.0)
    else
      base_price
    end
  end
  
  def calculate_seasonal_price(base_price, context)
    current_month = Date.current.month
    seasonal_adjustments = config['seasonal_adjustments'] || {}
    
    adjustment = seasonal_adjustments[current_month.to_s]
    return base_price unless adjustment
    
    if adjustment > 0
      base_price * (1 + adjustment / 100.0)
    else
      base_price * (1 - adjustment.abs / 100.0)
    end
  end
  
  def calculate_bundle_price(base_price, context)
    bundle_size = context[:quantity] || 1
    
    # Tiered bundle discounts
    discount = case bundle_size
    when 2..4
      config['bundle_discount_tier1'] || 5
    when 5..9
      config['bundle_discount_tier2'] || 10
    when 10..Float::INFINITY
      config['bundle_discount_tier3'] || 15
    else
      0
    end
    
    base_price * (1 - discount / 100.0)
  end
  
  def calculate_volume_price(base_price, context)
    quantity = context[:quantity] || 1
    
    # Volume-based pricing tiers
    tiers = config['volume_tiers'] || [
      { min: 10, discount: 5 },
      { min: 50, discount: 10 },
      { min: 100, discount: 15 }
    ]
    
    applicable_tier = tiers.select { |t| quantity >= t['min'] }.max_by { |t| t['min'] }
    
    if applicable_tier
      base_price * (1 - applicable_tier['discount'] / 100.0)
    else
      base_price
    end
  end
  
  def calculate_ai_optimized_price(base_price, context)
    # Use ML model to predict optimal price
    DynamicPricingService.new(product).optimal_price || base_price
  end
  
  def apply_price_bounds(price)
    price = [price, min_price_cents].max if min_price_cents
    price = [price, max_price_cents].min if max_price_cents
    price.round
  end
  
  def validate_price_bounds
    if min_price_cents && max_price_cents && min_price_cents > max_price_cents
      errors.add(:min_price_cents, "cannot be greater than max price")
    end
  end
  
  def validate_date_range
    if start_date && end_date && start_date > end_date
      errors.add(:start_date, "cannot be after end date")
    end
  end
end

