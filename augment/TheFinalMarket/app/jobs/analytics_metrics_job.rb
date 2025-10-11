class AnalyticsMetricsJob < ApplicationJob
  queue_as :default
  
  def perform(date = Date.current)
    # Record daily metrics
    record_revenue_metrics(date)
    record_order_metrics(date)
    record_customer_metrics(date)
    record_product_metrics(date)
    record_traffic_metrics(date)
    record_conversion_metrics(date)
  end
  
  private
  
  def record_revenue_metrics(date)
    # Total revenue
    total_revenue = Order.where(created_at: date.all_day, status: 'completed')
                        .sum(:total_cents) / 100.0
    
    AnalyticsMetric.record('daily_revenue', total_revenue, :revenue, date)
    
    # Average order value
    avg_order_value = Order.where(created_at: date.all_day, status: 'completed')
                          .average(:total_cents)&.to_f || 0
    
    AnalyticsMetric.record('avg_order_value', avg_order_value / 100.0, :revenue, date)
  end
  
  def record_order_metrics(date)
    # Total orders
    total_orders = Order.where(created_at: date.all_day, status: 'completed').count
    AnalyticsMetric.record('daily_orders', total_orders, :orders, date)
    
    # Pending orders
    pending_orders = Order.where(created_at: date.all_day, status: 'pending').count
    AnalyticsMetric.record('pending_orders', pending_orders, :orders, date)
    
    # Cancelled orders
    cancelled_orders = Order.where(created_at: date.all_day, status: 'cancelled').count
    AnalyticsMetric.record('cancelled_orders', cancelled_orders, :orders, date)
  end
  
  def record_customer_metrics(date)
    # New customers
    new_customers = User.where(created_at: date.all_day).count
    AnalyticsMetric.record('new_customers', new_customers, :customers, date)
    
    # Active customers (made a purchase)
    active_customers = Order.where(created_at: date.all_day, status: 'completed')
                           .distinct
                           .count(:user_id)
    AnalyticsMetric.record('active_customers', active_customers, :customers, date)
    
    # Total customers
    total_customers = User.count
    AnalyticsMetric.record('total_customers', total_customers, :customers, date)
  end
  
  def record_product_metrics(date)
    # Products sold
    products_sold = LineItem.joins(:order)
                           .where(orders: { created_at: date.all_day, status: 'completed' })
                           .sum(:quantity)
    
    AnalyticsMetric.record('products_sold', products_sold, :products, date)
    
    # Unique products sold
    unique_products = LineItem.joins(:order)
                             .where(orders: { created_at: date.all_day, status: 'completed' })
                             .distinct
                             .count(:product_id)
    
    AnalyticsMetric.record('unique_products_sold', unique_products, :products, date)
  end
  
  def record_traffic_metrics(date)
    # These would come from analytics integration (Google Analytics, etc.)
    # For now, record placeholder values
    AnalyticsMetric.record('page_views', 0, :traffic, date)
    AnalyticsMetric.record('unique_visitors', 0, :traffic, date)
    AnalyticsMetric.record('sessions', 0, :traffic, date)
  end
  
  def record_conversion_metrics(date)
    # Conversion rate
    sessions = 1000 # Would come from analytics
    orders = Order.where(created_at: date.all_day, status: 'completed').count
    conversion_rate = sessions > 0 ? (orders.to_f / sessions * 100).round(2) : 0
    
    AnalyticsMetric.record('conversion_rate', conversion_rate, :conversion, date)
    
    # Cart abandonment rate
    carts = Cart.where(created_at: date.all_day).joins(:cart_items).distinct.count
    cart_abandonment = carts > 0 ? ((carts - orders).to_f / carts * 100).round(2) : 0
    
    AnalyticsMetric.record('cart_abandonment_rate', cart_abandonment, :conversion, date)
  end
end

