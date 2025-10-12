class AnalyticsMetric < ApplicationRecord
  validates :metric_name, presence: true, uniqueness: { scope: [:metric_type, :date] }
  validates :metric_type, presence: true
  validates :date, presence: true
  
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :for_metric, ->(name) { where(metric_name: name) }
  scope :for_type, ->(type) { where(metric_type: type) }
  scope :recent, -> { where('date > ?', 30.days.ago) }
  
  # Metric types
  enum metric_type: {
    revenue: 0,
    orders: 1,
    customers: 2,
    products: 3,
    traffic: 4,
    conversion: 5,
    engagement: 6,
    retention: 7
  }
  
  # Record a metric
  def self.record(metric_name, value, metric_type, date = Date.current, dimensions = {})
    create_or_find_by!(
      metric_name: metric_name,
      metric_type: metric_type,
      date: date
    ) do |metric|
      metric.value = value
      metric.dimensions = dimensions
    end
  end
  
  # Get metric value for date
  def self.value_for(metric_name, date = Date.current)
    find_by(metric_name: metric_name, date: date)&.value || 0
  end
  
  # Get metric trend
  def self.trend(metric_name, days = 30)
    for_metric(metric_name)
      .where('date > ?', days.days.ago)
      .order(date: :asc)
      .pluck(:date, :value)
  end
  
  # Calculate growth rate
  def self.growth_rate(metric_name, period = 7)
    current = value_for(metric_name, Date.current)
    previous = value_for(metric_name, period.days.ago)
    
    return 0 if previous.zero?
    
    ((current - previous) / previous.to_f * 100).round(2)
  end
end

