class PricingRuleCalculationService
  attr_reader :rule

  def initialize(rule)
    @rule = rule
  end

  def calculate_price(base_price, context = {})
    Rails.logger.debug("Calculating price for rule ID: #{rule.id}, type: #{rule.rule_type}, base price: #{base_price}")

    begin
      return base_price unless rule.active? && applicable?(context)

      new_price = execute_price_calculation(base_price, context)

      # Apply min/max constraints
      final_price = apply_price_bounds(new_price)

      Rails.logger.info("Calculated price for rule ID: #{rule.id}: #{base_price} -> #{final_price}")
      final_price
    rescue => e
      Rails.logger.error("Failed to calculate price for rule ID: #{rule.id}. Error: #{e.message}")
      base_price
    end
  end

  def applicable?(context = {})
    Rails.logger.debug("Checking if rule ID: #{rule.id} is applicable")

    begin
      return false unless rule.active?
      return false if rule.start_date && rule.start_date > Date.current
      return false if rule.end_date && rule.end_date < Date.current

      # Check all conditions
      rule.pricing_rule_conditions.all? { |condition| condition.met?(context) }
    rescue => e
      Rails.logger.error("Failed to check if rule ID: #{rule.id} is applicable. Error: #{e.message}")
      false
    end
  end

  def price_calculation_summary(base_price, context = {})
    Rails.logger.debug("Generating price calculation summary for rule ID: #{rule.id}")

    begin
      summary = {
        rule_id: rule.id,
        rule_name: rule.name,
        rule_type: rule.rule_type,
        base_price: base_price,
        calculated_price: calculate_price(base_price, context),
        applicable: applicable?(context),
        conditions_met: rule.pricing_rule_conditions.map { |c| { id: c.id, met: c.met?(context) } },
        price_bounds: {
          min_price: rule.min_price_cents,
          max_price: rule.max_price_cents
        },
        context: context
      }

      Rails.logger.debug("Generated price calculation summary for rule ID: #{rule.id}")
      summary
    rescue => e
      Rails.logger.error("Failed to generate price calculation summary for rule ID: #{rule.id}. Error: #{e.message}")
      {}
    end
  end

  private

  def execute_price_calculation(base_price, context)
    Rails.logger.debug("Executing price calculation for rule ID: #{rule.id}, type: #{rule.rule_type}")

    begin
      case rule.rule_type.to_sym
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
        Rails.logger.warn("Unknown rule type: #{rule.rule_type}")
        base_price
      end
    rescue => e
      Rails.logger.error("Failed to execute price calculation for rule ID: #{rule.id}. Error: #{e.message}")
      base_price
    end
  end

  def calculate_time_based_price(base_price, context)
    Rails.logger.debug("Calculating time-based price for rule ID: #{rule.id}")

    begin
      current_hour = Time.current.hour

      # Happy hour pricing (e.g., 20% off between 2-4 PM)
      if rule.config['happy_hours']&.include?(current_hour)
        discount_percentage = rule.config['happy_hour_discount'] || 20
        base_price * (1 - discount_percentage / 100.0)
      # Flash sale
      elsif rule.config['flash_sale_active']
        base_price * (1 - (rule.config['flash_sale_discount'] || 30) / 100.0)
      else
        base_price
      end
    rescue => e
      Rails.logger.error("Failed to calculate time-based price for rule ID: #{rule.id}. Error: #{e.message}")
      base_price
    end
  end

  def calculate_inventory_based_price(base_price, context)
    Rails.logger.debug("Calculating inventory-based price for rule ID: #{rule.id}")

    begin
      stock_level = rule.product.stock_quantity || 0
      low_stock_threshold = rule.config['low_stock_threshold'] || 10

      if stock_level <= low_stock_threshold && stock_level > 0
        # Clearance pricing - increase discount as stock decreases
        discount_percentage = rule.config['clearance_discount'] || 25
        discount_percentage += (low_stock_threshold - stock_level) * 2 # Additional 2% per unit
        base_price * (1 - [discount_percentage, 50].min / 100.0) # Max 50% off
      elsif stock_level == 0
        base_price # No discount if out of stock
      else
        base_price
      end
    rescue => e
      Rails.logger.error("Failed to calculate inventory-based price for rule ID: #{rule.id}. Error: #{e.message}")
      base_price
    end
  end

  def calculate_demand_based_price(base_price, context)
    Rails.logger.debug("Calculating demand-based price for rule ID: #{rule.id}")

    begin
      # Get recent view count and purchase velocity
      views_last_24h = rule.product.product_views.where('created_at > ?', 24.hours.ago).count
      purchases_last_24h = rule.product.line_items.where('created_at > ?', 24.hours.ago).count

      demand_score = (views_last_24h * 0.1) + (purchases_last_24h * 10)

      # High demand = price increase (surge pricing)
      if demand_score > (rule.config['high_demand_threshold'] || 50)
        surge_percentage = rule.config['surge_percentage'] || 15
        base_price * (1 + surge_percentage / 100.0)
      # Low demand = price decrease
      elsif demand_score < (rule.config['low_demand_threshold'] || 5)
        discount_percentage = rule.config['low_demand_discount'] || 10
        base_price * (1 - discount_percentage / 100.0)
      else
        base_price
      end
    rescue => e
      Rails.logger.error("Failed to calculate demand-based price for rule ID: #{rule.id}. Error: #{e.message}")
      base_price
    end
  end

  def calculate_competitor_based_price(base_price, context)
    Rails.logger.debug("Calculating competitor-based price for rule ID: #{rule.id}")

    begin
      # Get competitor prices
      competitor_prices = CompetitorPrice.active
        .where(product_identifier: rule.product.sku)
        .where('updated_at > ?', 24.hours.ago)
        .pluck(:price_cents)

      return base_price if competitor_prices.empty?

      avg_competitor_price = competitor_prices.sum / competitor_prices.size
      min_competitor_price = competitor_prices.min

      strategy = rule.config['competitor_strategy'] || 'match_lowest'

      case strategy
      when 'match_lowest'
        # Match the lowest competitor price
        [min_competitor_price, base_price].min
      when 'undercut'
        # Undercut by percentage
        undercut_percentage = rule.config['undercut_percentage'] || 5
        min_competitor_price * (1 - undercut_percentage / 100.0)
      when 'match_average'
        # Match average competitor price
        avg_competitor_price
      when 'premium'
        # Stay above average by percentage
        premium_percentage = rule.config['premium_percentage'] || 10
        avg_competitor_price * (1 + premium_percentage / 100.0)
      else
        base_price
      end
    rescue => e
      Rails.logger.error("Failed to calculate competitor-based price for rule ID: #{rule.id}. Error: #{e.message}")
      base_price
    end
  end

  def calculate_seasonal_price(base_price, context)
    Rails.logger.debug("Calculating seasonal price for rule ID: #{rule.id}")

    begin
      current_month = Date.current.month
      seasonal_adjustments = rule.config['seasonal_adjustments'] || {}

      adjustment = seasonal_adjustments[current_month.to_s]
      return base_price unless adjustment

      if adjustment > 0
        base_price * (1 + adjustment / 100.0)
      else
        base_price * (1 - adjustment.abs / 100.0)
      end
    rescue => e
      Rails.logger.error("Failed to calculate seasonal price for rule ID: #{rule.id}. Error: #{e.message}")
      base_price
    end
  end

  def calculate_bundle_price(base_price, context)
    Rails.logger.debug("Calculating bundle price for rule ID: #{rule.id}")

    begin
      bundle_size = context[:quantity] || 1

      # Tiered bundle discounts
      discount = case bundle_size
      when 2..4
        rule.config['bundle_discount_tier1'] || 5
      when 5..9
        rule.config['bundle_discount_tier2'] || 10
      when 10..Float::INFINITY
        rule.config['bundle_discount_tier3'] || 15
      else
        0
      end

      base_price * (1 - discount / 100.0)
    rescue => e
      Rails.logger.error("Failed to calculate bundle price for rule ID: #{rule.id}. Error: #{e.message}")
      base_price
    end
  end

  def calculate_volume_price(base_price, context)
    Rails.logger.debug("Calculating volume price for rule ID: #{rule.id}")

    begin
      quantity = context[:quantity] || 1

      # Volume-based pricing tiers
      tiers = rule.config['volume_tiers'] || [
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
    rescue => e
      Rails.logger.error("Failed to calculate volume price for rule ID: #{rule.id}. Error: #{e.message}")
      base_price
    end
  end

  def calculate_ai_optimized_price(base_price, context)
    Rails.logger.debug("Calculating AI-optimized price for rule ID: #{rule.id}")

    begin
      # Use ML model to predict optimal price
      DynamicPricingService.new(rule.product).optimal_price || base_price
    rescue => e
      Rails.logger.error("Failed to calculate AI-optimized price for rule ID: #{rule.id}. Error: #{e.message}")
      base_price
    end
  end

  def apply_price_bounds(price)
    Rails.logger.debug("Applying price bounds for rule ID: #{rule.id}, price: #{price}")

    begin
      bounded_price = price

      bounded_price = [bounded_price, rule.min_price_cents].max if rule.min_price_cents
      bounded_price = [bounded_price, rule.max_price_cents].min if rule.max_price_cents

      bounded_price.round
    rescue => e
      Rails.logger.error("Failed to apply price bounds for rule ID: #{rule.id}. Error: #{e.message}")
      price.round
    end
  end
end