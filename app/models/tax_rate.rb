class TaxRate < ApplicationRecord
  belongs_to :country
  
  validates :name, presence: true
  validates :rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  scope :active, -> { where(active: true) }
  scope :for_country, ->(country) { where(country: country) }
  scope :for_category, ->(category) { where(product_category: category) }
  
  # Calculate tax amount
  def calculate_tax(amount_cents)
    (amount_cents * rate / 100.0).round
  end
  
  # Get tax-inclusive amount
  def with_tax(amount_cents)
    amount_cents + calculate_tax(amount_cents)
  end
  
  # Get tax-exclusive amount (if tax is included in price)
  def without_tax(amount_cents)
    return amount_cents unless included_in_price?
    
    (amount_cents / (1 + rate / 100.0)).round
  end
end

