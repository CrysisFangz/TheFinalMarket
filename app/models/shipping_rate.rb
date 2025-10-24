cclass ShippingRate < ApplicationRecord
  belongs_to :shipping_zone

  validates :service_level, presence: true
  validates :base_rate_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :min_weight_grams, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_weight_grams, numericality: { greater_than: :min_weight_grams }, allow_nil: true
  validates :min_delivery_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :max_delivery_days, numericality: { greater_than_or_equal_to: :min_delivery_days }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :for_service, ->(level) { where(service_level: level) }

  # Service levels
  enum service_level: {
    economy: 0,
    standard: 1,
    express: 2,
    overnight: 3
  }

  # Delegate business logic to services
  def calculate_cost(weight_grams)
    ShippingCostCalculator.calculate(self, weight_grams)
  end

  def delivery_estimate
    DeliveryEstimate.new(min_delivery_days, max_delivery_days).to_s
  end

  def applies_to_weight?(weight_grams)
    ShippingRateValidator.applies_to_weight?(self, weight_grams)
  end
end

