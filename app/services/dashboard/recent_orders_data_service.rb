module Dashboard
  class RecentOrdersDataService
    def initialize(widget)
      @widget = widget
    end

    def fetch_data
      Rails.cache.fetch(cache_key, expires_in: 2.minutes) do
        limit = @widget.configuration['limit'] || 10
        Order.includes(:user)
             .where(status: 'completed')
             .order(created_at: :desc)
             .limit(limit)
             .map do |order|
          {
            id: order.id,
            total: order.total_cents / 100.0,
            created_at: order.created_at,
            customer: order.user.name
          }
        end
      end
    rescue StandardError => e
      Rails.logger.error("Error in RecentOrdersDataService: #{e.message}")
      []
    end

    private

    def cache_key
      "dashboard_widget_recent_orders_#{@widget.id}_#{@widget.updated_at.to_i}"
    end
  end
end