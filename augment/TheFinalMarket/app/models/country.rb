class Country < ApplicationRecord
  has_many :shipping_zone_countries, dependent: :destroy
  has_many :shipping_zones, through: :shipping_zone_countries
  has_many :tax_rates, dependent: :destroy
  
  validates :code, presence: true, uniqueness: true, length: { is: 2 }
  validates :name, presence: true
  
  scope :active, -> { where(active: true) }
  scope :supported, -> { where(supported_for_shipping: true) }
  scope :by_name, -> { order(:name) }
  
  # Get country by code
  def self.find_by_code(code)
    find_by(code: code.upcase)
  end
  
  # Get shipping zone for this country
  def shipping_zone
    shipping_zones.active.by_priority.first
  end
  
  # Get tax rate for this country
  def tax_rate_for(product_category = nil)
    if product_category
      tax_rates.active.find_by(product_category: product_category) ||
        tax_rates.active.find_by(product_category: nil)
    else
      tax_rates.active.find_by(product_category: nil)
    end
  end
  
  # Calculate tax for amount
  def calculate_tax(amount_cents, product_category = nil)
    rate = tax_rate_for(product_category)
    return 0 unless rate
    
    (amount_cents * rate.rate / 100.0).round
  end
  
  # Get currency for this country
  def currency
    Currency.find_by(code: currency_code) || Currency.base_currency
  end
  
  # Get locale for this country
  def locale
    locale_code || "en-#{code}"
  end
  
  # Check if country requires customs
  def requires_customs?
    requires_customs == true
  end
  
  # Get phone code
  def phone_code_formatted
    "+#{phone_code}"
  end
end

