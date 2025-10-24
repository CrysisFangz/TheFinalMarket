class PricingRuleConditionComparisonService
  attr_reader :condition

  def initialize(condition)
    @condition = condition
  end

  def compare_values(actual, expected)
    Rails.logger.debug("Comparing values for condition ID: #{condition.id}, actual: #{actual}, expected: #{expected}, operator: #{condition.operator}")

    begin
      result = case condition.operator.to_sym
      when :equals
        compare_equals(actual, expected)
      when :not_equals
        compare_not_equals(actual, expected)
      when :greater_than
        compare_greater_than(actual, expected)
      when :less_than
        compare_less_than(actual, expected)
      when :greater_than_or_equal
        compare_greater_than_or_equal(actual, expected)
      when :less_than_or_equal
        compare_less_than_or_equal(actual, expected)
      when :between
        compare_between(actual, expected)
      when :in_list
        compare_in_list(actual, expected)
      when :not_in_list
        compare_not_in_list(actual, expected)
      else
        Rails.logger.warn("Unknown operator: #{condition.operator}")
        false
      end

      Rails.logger.debug("Comparison result for condition ID: #{condition.id}: #{result}")
      result
    rescue => e
      Rails.logger.error("Failed to compare values for condition ID: #{condition.id}. Error: #{e.message}")
      false
    end
  end

  def parse_value(val)
    Rails.logger.debug("Parsing value for condition ID: #{condition.id}: #{val}")

    begin
      return val if val.is_a?(Numeric)
      val.to_s.match?(/^\d+(\.\d+)?$/) ? val.to_f : val
    rescue => e
      Rails.logger.error("Failed to parse value for condition ID: #{condition.id}. Error: #{e.message}")
      val
    end
  end

  def parse_range(val)
    Rails.logger.debug("Parsing range for condition ID: #{condition.id}: #{val}")

    begin
      parts = val.to_s.split('-')
      if parts.length == 2
        { min: parts[0].to_f, max: parts[1].to_f }
      else
        Rails.logger.error("Invalid range format for condition ID: #{condition.id}: #{val}")
        { min: 0, max: 0 }
      end
    rescue => e
      Rails.logger.error("Failed to parse range for condition ID: #{condition.id}. Error: #{e.message}")
      { min: 0, max: 0 }
    end
  end

  def parse_list(val)
    Rails.logger.debug("Parsing list for condition ID: #{condition.id}: #{val}")

    begin
      val.to_s.split(',').map(&:strip)
    rescue => e
      Rails.logger.error("Failed to parse list for condition ID: #{condition.id}. Error: #{e.message}")
      []
    end
  end

  def format_comparison_result(actual, expected, result)
    {
      condition_id: condition.id,
      condition_type: condition.condition_type,
      operator: condition.operator,
      actual_value: actual,
      expected_value: expected,
      comparison_result: result,
      timestamp: Time.current
    }
  end

  private

  def compare_equals(actual, expected)
    actual == parse_value(expected)
  end

  def compare_not_equals(actual, expected)
    actual != parse_value(expected)
  end

  def compare_greater_than(actual, expected)
    actual.to_f > parse_value(expected).to_f
  end

  def compare_less_than(actual, expected)
    actual.to_f < parse_value(expected).to_f
  end

  def compare_greater_than_or_equal(actual, expected)
    actual.to_f >= parse_value(expected).to_f
  end

  def compare_less_than_or_equal(actual, expected)
    actual.to_f <= parse_value(expected).to_f
  end

  def compare_between(actual, expected)
    range = parse_range(expected)
    actual.to_f >= range[:min] && actual.to_f <= range[:max]
  end

  def compare_in_list(actual, expected)
    list = parse_list(expected)
    list.include?(actual.to_s)
  end

  def compare_not_in_list(actual, expected)
    list = parse_list(expected)
    !list.include?(actual.to_s)
  end
end