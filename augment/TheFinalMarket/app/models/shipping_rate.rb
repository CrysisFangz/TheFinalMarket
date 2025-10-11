class ShippingRate < ApplicationRecord
  belongs_to :shipping_zone
  
  validates :service_level, presence: true
  validates :base_rate_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  scope :active, -> { where(active: true) }
  scope :for_service, ->(level) { where(service_level: level) }
  
  # Service levels
  enum service_level: {
    economy: 0,
    standard: 1,
    express: 2,
    overnight: 3
  }
  
  # Calculate shipping cost based on weight
  def calculate_cost(weight_grams)
    cost = base_rate_cents
    
    # Add per-kg rate if applicable
    if per_kg_rate_cents && weight_grams > 0
      kg = weight_grams / 1000.0
      cost += (kg * per_kg_rate_cents).round
    end
    
    # Apply minimum
    cost = [cost, min_rate_cents].max if min_rate_cents
    
    # Apply maximum
    cost = [cost, max_rate_cents].min if max_rate_cents
    
    cost
  end
  
  # Get delivery estimate
  def delivery_estimate
    if min_delivery_days == max_delivery_days
      "#{min_delivery_days} business days"
    else
      "#{min_delivery_days}-#{max_delivery_days} business days"
    end
  end
  
  # Check if rate applies to weight
  def applies_to_weight?(weight_grams)
    return false if weight_grams < min_weight_grams
    return false if max_weight_grams && weight_grams > max_weight_grams
    true
  end
end

