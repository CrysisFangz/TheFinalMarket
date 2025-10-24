class TaxRate < ApplicationRecord
  belongs_to :country

  # Add included_in_price field
  attribute :included_in_price, :boolean, default: false

  validates :name, presence: true
  validates :rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :included_in_price, inclusion: { in: [true, false] }
  
  scope :active, -> { where(active: true) }
  scope :for_country, ->(country) { where(country: country) }
  scope :for_category, ->(category) { where(product_category: category) }
  
  # Delegate tax calculations to TaxCalculator service for decoupling and performance
  def calculate_tax(amount_cents)
    TaxCalculator.calculate_tax(self, amount_cents)
  end

  def with_tax(amount_cents)
    TaxCalculator.with_tax(self, amount_cents)
  end

  def without_tax(amount_cents)
    TaxCalculator.without_tax(self, amount_cents)
  end
end

