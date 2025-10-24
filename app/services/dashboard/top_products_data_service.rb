module Dashboard
  class TopProductsDataService
    def initialize(widget)
      @widget = widget
    end

    def fetch_data
      Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
        limit = @widget.configuration['limit'] || 10
        LineItem.joins(:order, :product)
                .where(orders: { created_at: 30.days.ago..Time.current, status: 'completed' })
                .group('products.name')
                .sum(:quantity)
                .sort_by { |_, qty| -qty }
                .first(limit)
                .to_h
      end
    rescue StandardError => e
      Rails.logger.error("Error in TopProductsDataService: #{e.message}")
      {}
    end

    private

    def cache_key
      "dashboard_widget_top_products_#{@widget.id}_#{@widget.updated_at.to_i}"
    end
  end
end