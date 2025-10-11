class ShippingZone < ApplicationRecord
  has_many :shipping_zone_countries, dependent: :destroy
  has_many :countries, through: :shipping_zone_countries
  has_many :shipping_rates, dependent: :destroy
  
  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  
  scope :active, -> { where(active: true) }
  scope :by_priority, -> { order(priority: :asc) }
  
  # Find zone for a country
  def self.for_country(country_code)
    joins(:countries)
      .where(countries: { code: country_code })
      .active
      .by_priority
      .first
  end
  
  # Check if zone includes a country
  def includes_country?(country_code)
    countries.exists?(code: country_code)
  end
  
  # Get shipping rate for weight and service
  def rate_for(weight_grams, service_level = 'standard')
    shipping_rates
      .active
      .where(service_level: service_level)
      .where('min_weight_grams <= ?', weight_grams)
      .where('max_weight_grams >= ? OR max_weight_grams IS NULL', weight_grams)
      .order(min_weight_grams: :desc)
      .first
  end
  
  # Calculate shipping cost
  def calculate_shipping(weight_grams, service_level = 'standard')
    rate = rate_for(weight_grams, service_level)
    return nil unless rate
    
    rate.calculate_cost(weight_grams)
  end
  
  # Get estimated delivery time
  def estimated_delivery_days(service_level = 'standard')
    rate = shipping_rates.active.find_by(service_level: service_level)
    return nil unless rate
    
    {
      min: rate.min_delivery_days,
      max: rate.max_delivery_days
    }
  end
end

