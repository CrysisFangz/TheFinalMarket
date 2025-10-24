module Dashboard
  class KeyMetricsDataService
    def initialize(widget)
      @widget = widget
    end

    def fetch_data
      Rails.cache.fetch(cache_key, expires_in: 1.minute) do
        {
          total_revenue: AnalyticsMetric.value_for('daily_revenue', Date.current),
          total_orders: AnalyticsMetric.value_for('daily_orders', Date.current),
          new_customers: AnalyticsMetric.value_for('new_customers', Date.current),
          conversion_rate: AnalyticsMetric.value_for('conversion_rate', Date.current)
        }
      end
    rescue StandardError => e
      Rails.logger.error("Error in KeyMetricsDataService: #{e.message}")
      {}
    end

    private

    def cache_key
      "dashboard_widget_key_metrics_#{@widget.id}_#{Date.current.to_s}"
    end
  end
end