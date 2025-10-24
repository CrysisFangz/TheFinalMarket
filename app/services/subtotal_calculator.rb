# frozen_string_literal: true

# Service for calculating order item subtotals with high precision and error handling.
# Ensures asymptotic optimality (O(1)) and thread safety through immutable operations.
class SubtotalCalculator
  # Calculates the subtotal for an order item.
  # @param unit_price [BigDecimal] The unit price of the item.
  # @param quantity [Integer] The quantity of the item.
  # @return [BigDecimal] The calculated subtotal.
  # @raise [ArgumentError] If inputs are invalid.
  def self.calculate(unit_price, quantity)
    validate_inputs(unit_price, quantity)

    # Use BigDecimal for precise monetary calculations to avoid floating-point errors.
    unit_price * quantity
  rescue TypeError, ArgumentError => e
    # Log error and re-raise for resilience and observability.
    Rails.logger.error("Subtotal calculation failed: #{e.message}")
    raise ArgumentError, "Invalid inputs for subtotal calculation: #{e.message}"
  end

  private

  # Validates inputs for calculation.
  def self.validate_inputs(unit_price, quantity)
    unless unit_price.is_a?(Numeric) && unit_price >= 0
      raise ArgumentError, "Unit price must be a non-negative number"
    end

    unless quantity.is_a?(Integer) && quantity > 0
      raise ArgumentError, "Quantity must be a positive integer"
    end
  end
end