class ShippingCostCalculator
  include CircuitBreaker

  # Calculate shipping cost with asymptotic optimality and error handling
  def self.calculate(rate, weight_grams)
    return 0 if weight_grams <= 0

    cost = rate.base_rate_cents

    # Add per-kg rate if applicable
    if rate.per_kg_rate_cents && weight_grams > 0
      kg = weight_grams / 1000.0
      cost += (kg * rate.per_kg_rate_cents).round
    end

    # Apply minimum
    cost = [cost, rate.min_rate_cents].max if rate.min_rate_cents

    # Apply maximum
    cost = [cost, rate.max_rate_cents].min if rate.max_rate_cents

    cost
  rescue => e
    Rails.logger.error("Shipping cost calculation error: #{e.message}")
    0
  end
end