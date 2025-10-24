module Dashboard
  class CustomerChartDataService
    def initialize(widget)
      @widget = widget
    end

    def fetch_data
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        days = @widget.configuration['days'] || 30
        AnalyticsMetric.for_metric('new_customers')
                      .where('date > ?', days.days.ago)
                      .order(:date)
                      .pluck(:date, :value)
                      .to_h
      end
    rescue StandardError => e
      Rails.logger.error("Error in CustomerChartDataService: #{e.message}")
      {}
    end

    private

    def cache_key
      "dashboard_widget_customer_chart_#{@widget.id}_#{@widget.updated_at.to_i}"
    end
  end
end