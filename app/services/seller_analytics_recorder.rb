# Service for recording seller analytics data
class SellerAnalyticsRecorder
  include ServiceResultHelper

  def self.call(seller, date = Date.current, async: false)
    if async
      RecordSellerAnalyticsJob.perform_later(seller.id, date)
    else
      new(seller, date).call
    end
  end

  def initialize(seller, date)
    @seller = seller
    @date = date
    @analytics = SellerAnalytics.find_or_initialize_by(seller: seller, date: date)
  end

  def call
    return failure('Invalid seller') unless @seller.is_a?(User) && @seller.seller?
    return failure('Invalid date') unless @date.is_a?(Date)

    calculate_and_update_metrics
    success(@analytics)
  rescue StandardError => e
    failure("Error recording analytics: #{e.message}")
  end

  private

  def calculate_and_update_metrics
    calculator = SellerAnalyticsCalculator.new(@seller, @date)

    @analytics.update!(
      total_sales_cents: calculator.total_sales_cents,
      orders_count: calculator.orders_count,
      units_sold: calculator.units_sold,
      average_order_value_cents: calculator.average_order_value_cents,
      conversion_rate: calculator.conversion_rate,
      page_views: calculator.page_views,
      unique_visitors: calculator.unique_visitors,
      cart_additions: calculator.cart_additions,
      revenue_per_visitor_cents: calculator.revenue_per_visitor_cents,
      return_rate: calculator.return_rate,
      customer_satisfaction_score: calculator.customer_satisfaction_score
    )
  end
end