module Dashboard
  class WidgetDataPresenter
    def self.present(data, widget_type)
      case widget_type
      when 'revenue_chart', 'sales_chart', 'customer_chart'
        data
      when 'key_metrics'
        data
      when 'top_products'
        data
      when 'recent_orders'
        data
      else
        {}
      end
    rescue StandardError => e
      Rails.logger.error("Error presenting widget data for #{widget_type}: #{e.message}")
      {}
    end
  end
end