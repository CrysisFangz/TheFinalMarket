module Dashboard
  class RevenueChartDataService
    def initialize(widget)
      @widget = widget
      @circuit_breaker = CircuitBreakers::BaseCircuitBreaker.new('revenue_chart_data')
    end

    def fetch_data
      @circuit_breaker.execute do
        Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
          days = @widget.configuration['days'] || 30
          AnalyticsMetric.for_metric('daily_revenue')
                        .where('date > ?', days.days.ago)
                        .order(:date)
                        .pluck(:date, :value)
                        .to_h
        end
      end
    rescue CircuitBreakers::OpenError
      Rails.logger.warn("Circuit breaker open for revenue chart data")
      {}
    rescue StandardError => e
      Rails.logger.error("Error in RevenueChartDataService: #{e.message}")
      {}
    end

    private

    def cache_key
      "dashboard_widget_revenue_chart_#{@widget.id}_#{@widget.updated_at.to_i}"
    end
  end
end