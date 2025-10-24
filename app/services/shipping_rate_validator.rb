class ShippingRateValidator
  # Check if rate applies to weight with resilience
  def self.applies_to_weight?(rate, weight_grams)
    return false if weight_grams < rate.min_weight_grams
    return false if rate.max_weight_grams && weight_grams > rate.max_weight_grams
    true
  rescue => e
    Rails.logger.error("Shipping rate validation error: #{e.message}")
    false
  end
end