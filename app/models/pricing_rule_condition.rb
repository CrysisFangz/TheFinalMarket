class PricingRuleCondition < ApplicationRecord
  belongs_to :pricing_rule
  
  # Condition types
  enum condition_type: {
    time_of_day: 0,
    day_of_week: 1,
    stock_level: 2,
    view_count: 3,
    sales_velocity: 4,
    competitor_price: 5,
    user_segment: 6,
    cart_value: 7,
    product_age: 8,
    season: 9
  }
  
  # Operators
  enum operator: {
    equals: 0,
    not_equals: 1,
    greater_than: 2,
    less_than: 3,
    greater_than_or_equal: 4,
    less_than_or_equal: 5,
    between: 6,
    in_list: 7,
    not_in_list: 8
  }
  
  validates :condition_type, presence: true
  validates :operator, presence: true
  validates :value, presence: true
  
  # Check if condition is met
  def met?(context = {})
    actual_value = get_actual_value(context)
    compare_values(actual_value, value)
  end
  
  private
  
  def get_actual_value(context)
    case condition_type.to_sym
    when :time_of_day
      Time.current.hour
    when :day_of_week
      Date.current.wday # 0 = Sunday, 6 = Saturday
    when :stock_level
      pricing_rule.product.stock_quantity || 0
    when :view_count
      pricing_rule.product.product_views.where('created_at > ?', 24.hours.ago).count
    when :sales_velocity
      pricing_rule.product.line_items.where('created_at > ?', 7.days.ago).count
    when :competitor_price
      CompetitorPrice.active
                    .where(product_identifier: pricing_rule.product.sku)
                    .where('updated_at > ?', 24.hours.ago)
                    .average(:price_cents)
                    .to_i
    when :user_segment
      context[:user]&.user_segment
    when :cart_value
      context[:cart_total] || 0
    when :product_age
      (Date.current - pricing_rule.product.created_at.to_date).to_i
    when :season
      get_current_season
    else
      nil
    end
  end
  
  def compare_values(actual, expected)
    case operator.to_sym
    when :equals
      actual == parse_value(expected)
    when :not_equals
      actual != parse_value(expected)
    when :greater_than
      actual.to_f > parse_value(expected).to_f
    when :less_than
      actual.to_f < parse_value(expected).to_f
    when :greater_than_or_equal
      actual.to_f >= parse_value(expected).to_f
    when :less_than_or_equal
      actual.to_f <= parse_value(expected).to_f
    when :between
      range = parse_range(expected)
      actual.to_f >= range[:min] && actual.to_f <= range[:max]
    when :in_list
      parse_list(expected).include?(actual.to_s)
    when :not_in_list
      !parse_list(expected).include?(actual.to_s)
    else
      false
    end
  end
  
  def parse_value(val)
    return val if val.is_a?(Numeric)
    val.to_s.match?(/^\d+(\.\d+)?$/) ? val.to_f : val
  end
  
  def parse_range(val)
    parts = val.to_s.split('-')
    { min: parts[0].to_f, max: parts[1].to_f }
  end
  
  def parse_list(val)
    val.to_s.split(',').map(&:strip)
  end
  
  def get_current_season
    month = Date.current.month
    case month
    when 12, 1, 2 then 'winter'
    when 3, 4, 5 then 'spring'
    when 6, 7, 8 then 'summer'
    when 9, 10, 11 then 'fall'
    end
  end
end

