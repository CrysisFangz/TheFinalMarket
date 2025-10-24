module Dashboard
  class WidgetDataService
    def self.fetch_data(widget)
      service_class = service_for(widget.widget_type)
      service_class.new(widget).fetch_data
    rescue StandardError => e
      Rails.logger.error("Error fetching widget data for #{widget.widget_type}: #{e.message}")
      {}
    end

    private

    def self.service_for(widget_type)
      case widget_type
      when 'revenue_chart'
        RevenueChartDataService
      when 'sales_chart'
        SalesChartDataService
      when 'customer_chart'
        CustomerChartDataService
      when 'key_metrics'
        KeyMetricsDataService
      when 'top_products'
        TopProductsDataService
      when 'recent_orders'
        RecentOrdersDataService
      else
        raise ArgumentError, "Unknown widget type: #{widget_type}"
      end
    end
  end
end