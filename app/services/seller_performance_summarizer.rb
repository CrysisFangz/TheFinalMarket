# Service for summarizing seller performance
class SellerPerformanceSummarizer
  def self.call(seller, period = 30)
    new(seller, period).call
  end

  def initialize(seller, period)
    @seller = seller
    @period = period
    @analytics = SellerAnalytics.for_seller(seller)
                                .where('date > ?', @period.days.ago)
                                .order_by_date_desc
  end

  def call
    return {} if @analytics.empty?

    {
      total_revenue: total_revenue,
      total_orders: total_orders,
      total_units: total_units,
      avg_order_value: avg_order_value,
      avg_conversion_rate: avg_conversion_rate,
      total_page_views: total_page_views,
      total_visitors: total_visitors,
      avg_satisfaction: avg_satisfaction,
      trend: calculate_trend
    }
  end

  private

  def total_revenue
    (@analytics.sum(:total_sales_cents) / 100.0).round(2)
  end

  def total_orders
    @analytics.sum(:orders_count)
  end

  def total_units
    @analytics.sum(:units_sold)
  end

  def avg_order_value
    (@analytics.average(:average_order_value_cents).to_f / 100.0).round(2)
  end

  def avg_conversion_rate
    @analytics.average(:conversion_rate).to_f.round(2)
  end

  def total_page_views
    @analytics.sum(:page_views)
  end

  def total_visitors
    @analytics.sum(:unique_visitors)
  end

  def avg_satisfaction
    @analytics.average(:customer_satisfaction_score).to_f.round(2)
  end

  def calculate_trend
    return 'stable' if @analytics.count < 7

    recent_avg = @analytics.limit(7).average(:total_sales_cents).to_f
    previous_avg = @analytics.offset(7).limit(7).average(:total_sales_cents).to_f

    return 'stable' if previous_avg.zero?

    change = ((recent_avg - previous_avg) / previous_avg * 100).round(2)

    case
    when change > 10 then 'growing'
    when change < -10 then 'declining'
    else 'stable'
    end
  end
end