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
    evaluation_service.met?(context)
  end

  # Additional methods that delegate to services
  def actual_value(context = {})
    evaluation_service.get_actual_value(context)
  end

  def condition_summary
    evaluation_service.condition_summary
  end

  def validate_condition_data
    evaluation_service.validate_condition_data
  end

  def comparison_result(actual, expected)
    comparison_service.compare_values(actual, expected)
  end

  def format_comparison_result(actual, expected, result)
    comparison_service.format_comparison_result(actual, expected, result)
  end

  private

  def evaluation_service
    @evaluation_service ||= PricingRuleConditionEvaluationService.new(self)
  end

  def comparison_service
    @comparison_service ||= PricingRuleConditionComparisonService.new(self)
  end
end

