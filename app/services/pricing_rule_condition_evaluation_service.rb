class PricingRuleConditionEvaluationService
  attr_reader :condition

  def initialize(condition)
    @condition = condition
  end

  def met?(context = {})
    Rails.logger.debug("Evaluating condition ID: #{condition.id}, type: #{condition.condition_type}, operator: #{condition.operator}")

    begin
      actual_value = get_actual_value(context)
      result = compare_values(actual_value, condition.value)

      Rails.logger.debug("Condition evaluation result for ID: #{condition.id}: #{result}")
      result
    rescue => e
      Rails.logger.error("Failed to evaluate condition ID: #{condition.id}. Error: #{e.message}")
      false
    end
  end

  def get_actual_value(context)
    Rails.logger.debug("Getting actual value for condition ID: #{condition.id}, type: #{condition.condition_type}")

    begin
      value = case condition.condition_type.to_sym
      when :time_of_day
        get_time_of_day_value
      when :day_of_week
        get_day_of_week_value
      when :stock_level
        get_stock_level_value
      when :view_count
        get_view_count_value
      when :sales_velocity
        get_sales_velocity_value
      when :competitor_price
        get_competitor_price_value
      when :user_segment
        get_user_segment_value(context)
      when :cart_value
        get_cart_value_value(context)
      when :product_age
        get_product_age_value
      when :season
        get_season_value
      else
        Rails.logger.warn("Unknown condition type: #{condition.condition_type}")
        nil
      end

      Rails.logger.debug("Got actual value for condition ID: #{condition.id}: #{value}")
      value
    rescue => e
      Rails.logger.error("Failed to get actual value for condition ID: #{condition.id}. Error: #{e.message}")
      nil
    end
  end

  def condition_summary
    Rails.logger.debug("Generating condition summary for ID: #{condition.id}")

    begin
      summary = {
        id: condition.id,
        condition_type: condition.condition_type,
        operator: condition.operator,
        value: condition.value,
        pricing_rule_id: condition.pricing_rule_id,
        actual_value: get_actual_value({}),
        met: met?({}),
        created_at: condition.created_at,
        updated_at: condition.updated_at
      }

      Rails.logger.debug("Generated condition summary for ID: #{condition.id}")
      summary
    rescue => e
      Rails.logger.error("Failed to generate condition summary for ID: #{condition.id}. Error: #{e.message}")
      {}
    end
  end

  def validate_condition_data
    Rails.logger.debug("Validating condition data for ID: #{condition.id}")

    begin
      validation_result = {
        valid: true,
        errors: []
      }

      # Validate condition type
      unless PricingRuleCondition.condition_types.keys.include?(condition.condition_type)
        validation_result[:valid] = false
        validation_result[:errors] << "Invalid condition type: #{condition.condition_type}"
      end

      # Validate operator
      unless PricingRuleCondition.operators.keys.include?(condition.operator)
        validation_result[:valid] = false
        validation_result[:errors] << "Invalid operator: #{condition.operator}"
      end

      # Validate value based on condition type
      value_validation = validate_condition_value
      unless value_validation[:valid]
        validation_result[:valid] = false
        validation_result[:errors] << value_validation[:error]
      end

      Rails.logger.debug("Condition validation result for ID: #{condition.id}: #{validation_result}")
      validation_result
    rescue => e
      Rails.logger.error("Failed to validate condition data for ID: #{condition.id}. Error: #{e.message}")
      { valid: false, errors: [e.message] }
    end
  end

  private

  def get_time_of_day_value
    Time.current.hour
  end

  def get_day_of_week_value
    Date.current.wday # 0 = Sunday, 6 = Saturday
  end

  def get_stock_level_value
    condition.pricing_rule.product.stock_quantity || 0
  end

  def get_view_count_value
    condition.pricing_rule.product.product_views.where('created_at > ?', 24.hours.ago).count
  end

  def get_sales_velocity_value
    condition.pricing_rule.product.line_items.where('created_at > ?', 7.days.ago).count
  end

  def get_competitor_price_value
    CompetitorPrice.active
      .where(product_identifier: condition.pricing_rule.product.sku)
      .where('updated_at > ?', 24.hours.ago)
      .average(:price_cents)
      .to_i
  end

  def get_user_segment_value(context)
    context[:user]&.user_segment
  end

  def get_cart_value_value(context)
    context[:cart_total] || 0
  end

  def get_product_age_value
    (Date.current - condition.pricing_rule.product.created_at.to_date).to_i
  end

  def get_season_value
    month = Date.current.month
    case month
    when 12, 1, 2 then 'winter'
    when 3, 4, 5 then 'spring'
    when 6, 7, 8 then 'summer'
    when 9, 10, 11 then 'fall'
    end
  end

  def validate_condition_value
    case condition.condition_type.to_sym
    when :time_of_day
      validate_time_of_day_value
    when :day_of_week
      validate_day_of_week_value
    when :stock_level, :view_count, :sales_velocity, :product_age
      validate_numeric_value
    when :competitor_price, :cart_value
      validate_numeric_value
    when :user_segment
      validate_user_segment_value
    when :season
      validate_season_value
    else
      { valid: false, error: "Unknown condition type: #{condition.condition_type}" }
    end
  end

  def validate_time_of_day_value
    value = parse_value(condition.value)
    if value.is_a?(Numeric) && value >= 0 && value <= 23
      { valid: true }
    else
      { valid: false, error: 'Time of day must be between 0 and 23' }
    end
  end

  def validate_day_of_week_value
    value = parse_value(condition.value)
    if value.is_a?(Numeric) && value >= 0 && value <= 6
      { valid: true }
    else
      { valid: false, error: 'Day of week must be between 0 and 6' }
    end
  end

  def validate_numeric_value
    value = parse_value(condition.value)
    if value.is_a?(Numeric)
      { valid: true }
    else
      { valid: false, error: 'Value must be numeric' }
    end
  end

  def validate_user_segment_value
    # User segments are typically strings, so any string is valid
    { valid: true }
  end

  def validate_season_value
    valid_seasons = ['winter', 'spring', 'summer', 'fall']
    if valid_seasons.include?(condition.value.to_s.downcase)
      { valid: true }
    else
      { valid: false, error: "Season must be one of: #{valid_seasons.join(', ')}" }
    end
  end

  def parse_value(val)
    return val if val.is_a?(Numeric)
    val.to_s.match?(/^\d+(\.\d+)?$/) ? val.to_f : val
  end
end