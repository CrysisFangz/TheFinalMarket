class CompetitorPrice < ApplicationRecord
  # Track competitor pricing for price matching strategies
  
  validates :competitor_name, presence: true
  validates :product_identifier, presence: true # SKU or similar
  validates :price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp }, allow_blank: true
  
  scope :active, -> { where(active: true) }
  scope :for_product, ->(identifier) { where(product_identifier: identifier) }
  scope :recent, -> { where('updated_at > ?', 24.hours.ago) }
  scope :by_competitor, ->(name) { where(competitor_name: name) }
  
  # Get average competitor price for a product
  def self.average_price_for(product_identifier)
    active.for_product(product_identifier).recent.average(:price_cents)
  end
  
  # Get lowest competitor price for a product
  def self.lowest_price_for(product_identifier)
    active.for_product(product_identifier).recent.minimum(:price_cents)
  end
  
  # Get highest competitor price for a product
  def self.highest_price_for(product_identifier)
    active.for_product(product_identifier).recent.maximum(:price_cents)
  end
  
  # Check if price has changed significantly
  def significant_change?(threshold_percentage = 5)
    return false unless previous_price_cents
    
    change_percentage = ((price_cents - previous_price_cents).to_f / previous_price_cents * 100).abs
    change_percentage >= threshold_percentage
  end
  
  # Update price and track history
  def update_price!(new_price_cents)
    update!(
      previous_price_cents: price_cents,
      price_cents: new_price_cents,
      last_checked_at: Time.current
    )
  end
end

