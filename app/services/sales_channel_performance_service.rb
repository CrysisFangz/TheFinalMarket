class SalesChannelPerformanceService
  attr_reader :sales_channel

  def initialize(sales_channel)
    @sales_channel = sales_channel
  end

  def performance_metrics(start_date: 30.days.ago, end_date: Time.current)
    Rails.logger.info("Calculating performance metrics for SalesChannel ID: #{sales_channel.id} from #{start_date} to #{end_date}")
    analytics = sales_channel.channel_analytics.where(date: start_date..end_date)

    metrics = {
      total_orders: analytics.sum(:orders_count),
      total_revenue: analytics.sum(:revenue),
      average_order_value: analytics.average(:average_order_value).to_f.round(2),
      conversion_rate: analytics.average(:conversion_rate).to_f.round(2),
      customer_count: analytics.sum(:unique_customers),
      return_rate: analytics.average(:return_rate).to_f.round(2)
    }

    Rails.logger.info("Performance metrics calculated for SalesChannel ID: #{sales_channel.id}")
    metrics
  rescue StandardError => e
    Rails.logger.error("Error calculating performance metrics for SalesChannel ID: #{sales_channel.id} - #{e.message}")
    {}
  end
end