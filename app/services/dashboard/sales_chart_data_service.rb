module Dashboard
  class SalesChartDataService
    def initialize(widget)
      @widget = widget
    end

    def fetch_data
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        days = @widget.configuration['days'] || 30
        AnalyticsMetric.for_metric('daily_orders')
                      .where('date > ?', days.days.ago)
                      .order(:date)
                      .pluck(:date, :value)
                      .to_h
      end
    rescue StandardError => e
      Rails.logger.error("Error in SalesChartDataService: #{e.message}")
      {}
    end

    private

    def cache_key
      "dashboard_widget_sales_chart_#{@widget.id}_#{@widget.updated_at.to_i}"
    end
  end
end