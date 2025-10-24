# Service for querying seller analytics data
class SellerAnalyticsQueryService
  def self.top_products(seller, limit = 10)
    seller.products
          .joins(:line_items)
          .select('products.*, SUM(line_items.quantity) as total_sold, SUM(line_items.total_cents) as total_revenue')
          .group('products.id')
          .order('total_revenue DESC')
          .limit(limit)
  end

  def self.sales_by_category(seller, period = 30)
    seller.products
          .joins(:line_items)
          .joins('INNER JOIN orders ON line_items.order_id = orders.id')
          .where('orders.created_at > ?', period.days.ago)
          .group('products.category')
          .select('products.category, SUM(line_items.total_cents) as revenue, SUM(line_items.quantity) as units')
          .order('revenue DESC')
  end

  def self.customer_demographics(seller)
    customers = User.joins(:orders)
                   .where(orders: { seller_id: seller.id })
                   .distinct

    {
      total_customers: customers.count,
      repeat_customers: customers.where('(SELECT COUNT(*) FROM orders WHERE user_id = users.id AND seller_id = ?) > 1', seller.id).count,
      average_lifetime_value: customers.joins(:orders).where(orders: { seller_id: seller.id }).average('orders.total_cents').to_f / 100.0,
      top_locations: customers.group(:country).count.sort_by { |k, v| -v }.first(5)
    }
  end
end