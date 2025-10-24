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
    calculation_service.price_change_percentage
  end

  def price_increased?
    calculation_service.price_increased?
  end

  def price_decreased?
    calculation_service.price_decreased?
  end

  def automated?
    calculation_service.automated?
  end

  def manual?
    calculation_service.manual?
  end

  # Additional methods that delegate to services
  def price_change_amount
    calculation_service.price_change_amount
  end

  def price_change_summary
    calculation_service.price_change_summary
  end

  def impact_analysis
    calculation_service.impact_analysis
  end

  def generate_report(time_range = :last_30_days)
    analytics_service.generate_price_change_report(time_range)
  end

  def price_volatility
    analytics_service.calculate_price_volatility
  end

  def price_trends
    analytics_service.analyze_price_trends
  end

  def future_price_prediction(days_ahead = 30)
    analytics_service.predict_future_price(days_ahead)
  end

  private

  def track_price_change_metrics
    analytics_service.track_price_change_metrics
  end

  def calculation_service
    @calculation_service ||= PriceChangeCalculationService.new(self)
  end

  def analytics_service
    @analytics_service ||= PriceChangeAnalyticsService.new(self)
  end
end

