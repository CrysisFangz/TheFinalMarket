# frozen_string_literal: true

class Admin::RealTimeAnalyticsService
  def fetch_current_visitors
    Ahoy::Visit.where('started_at > ?', 15.minutes.ago).count
  end

  def fetch_active_carts
    Cart.where('updated_at > ?', 1.hour.ago).count
  end

  def fetch_recent_orders
    Order.where('created_at > ?', 1.hour.ago)
  end

  def fetch_recent_events
    Ahoy::Event.where('time > ?', 15.minutes.ago)
                .order(time: :desc)
                .limit(50)
  end
end