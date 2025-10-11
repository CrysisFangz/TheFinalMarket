class DashboardWidget < ApplicationRecord
  belongs_to :user
  
  validates :widget_type, presence: true
  validates :title, presence: true
  
  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position) }
  
  # Widget types
  WIDGET_TYPES = %w[
    revenue_chart
    sales_chart
    customer_chart
    product_chart
    conversion_funnel
    top_products
    recent_orders
    customer_segments
    key_metrics
    cohort_heatmap
  ].freeze
  
  validates :widget_type, inclusion: { in: WIDGET_TYPES }
  
  # Get widget data
  def data
    case widget_type
    when 'revenue_chart'
      revenue_chart_data
    when 'sales_chart'
      sales_chart_data
    when 'customer_chart'
      customer_chart_data
    when 'key_metrics'
      key_metrics_data
    when 'top_products'
      top_products_data
    when 'recent_orders'
      recent_orders_data
    else
      {}
    end
  end
  
  private
  
  def revenue_chart_data
    days = configuration['days'] || 30
    AnalyticsMetric.for_metric('daily_revenue')
                  .where('date > ?', days.days.ago)
                  .order(:date)
                  .pluck(:date, :value)
                  .to_h
  end
  
  def sales_chart_data
    days = configuration['days'] || 30
    AnalyticsMetric.for_metric('daily_orders')
                  .where('date > ?', days.days.ago)
                  .order(:date)
                  .pluck(:date, :value)
                  .to_h
  end
  
  def customer_chart_data
    days = configuration['days'] || 30
    AnalyticsMetric.for_metric('new_customers')
                  .where('date > ?', days.days.ago)
                  .order(:date)
                  .pluck(:date, :value)
                  .to_h
  end
  
  def key_metrics_data
    {
      total_revenue: AnalyticsMetric.value_for('daily_revenue', Date.current),
      total_orders: AnalyticsMetric.value_for('daily_orders', Date.current),
      new_customers: AnalyticsMetric.value_for('new_customers', Date.current),
      conversion_rate: AnalyticsMetric.value_for('conversion_rate', Date.current)
    }
  end
  
  def top_products_data
    limit = configuration['limit'] || 10
    
    LineItem.joins(:order, :product)
            .where(orders: { created_at: 30.days.ago..Time.current, status: 'completed' })
            .group('products.name')
            .sum(:quantity)
            .sort_by { |_, qty| -qty }
            .first(limit)
            .to_h
  end
  
  def recent_orders_data
    limit = configuration['limit'] || 10
    
    Order.where(status: 'completed')
         .order(created_at: :desc)
         .limit(limit)
         .map do |order|
      {
        id: order.id,
        total: order.total_cents / 100.0,
        created_at: order.created_at,
        customer: order.user.name
      }
    end
  end
end

