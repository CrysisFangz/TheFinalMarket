class PriceChange < ApplicationRecord
  belongs_to :product
  belongs_to :pricing_rule, optional: true
  belongs_to :user, optional: true # Who made the manual change
  
  validates :old_price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :new_price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_product, ->(product) { where(product: product) }
  scope :automated, -> { where.not(pricing_rule_id: nil) }
  scope :manual, -> { where(pricing_rule_id: nil) }
  scope :today, -> { where('created_at >= ?', Date.current.beginning_of_day) }
  scope :this_week, -> { where('created_at >= ?', 1.week.ago) }
  
  after_create :track_price_change_metrics
  
  def price_change_percentage
    return 0 if old_price_cents.zero?
    ((new_price_cents - old_price_cents).to_f / old_price_cents * 100).round(2)
  end
  
  def price_increased?
    new_price_cents > old_price_cents
  end
  
  def price_decreased?
    new_price_cents < old_price_cents
  end
  
  def automated?
    pricing_rule_id.present?
  end
  
  def manual?
    !automated?
  end
  
  private
  
  def track_price_change_metrics
    # Track metrics for analytics
    PricingAnalyticsService.track_price_change(self)
  end
end

