class SellerAnalytics < ApplicationRecord
  belongs_to :seller, class_name: 'User'
  
  validates :date, presence: true
  validates :seller, presence: true
  
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :recent, -> { where('date > ?', 30.days.ago) }
  
  # Record daily analytics
  def self.record_for_seller(seller, date = Date.current)
    analytics = find_or_create_by!(seller: seller, date: date)
    
    # Calculate metrics
    orders = seller.orders.where('DATE(created_at) = ?', date)
    products = seller.products
    
    analytics.update!(
      total_sales_cents: orders.sum(:total_cents),
      orders_count: orders.count,
      units_sold: orders.joins(:line_items).sum('line_items.quantity'),
      average_order_value_cents: orders.any? ? (orders.sum(:total_cents) / orders.count) : 0,
      conversion_rate: calculate_conversion_rate(seller, date),
      page_views: calculate_page_views(seller, date),
      unique_visitors: calculate_unique_visitors(seller, date),
      cart_additions: calculate_cart_additions(seller, date),
      revenue_per_visitor_cents: calculate_revenue_per_visitor(seller, date),
      return_rate: calculate_return_rate(seller, date),
      customer_satisfaction_score: calculate_satisfaction_score(seller, date)
    )
    
    analytics
  end
  
  # Get performance summary
  def self.performance_summary(seller, period = 30)
    analytics = where(seller: seller)
               .where('date > ?', period.days.ago)
               .order(date: :desc)
    
    {
      total_revenue: analytics.sum(:total_sales_cents) / 100.0,
      total_orders: analytics.sum(:orders_count),
      total_units: analytics.sum(:units_sold),
      avg_order_value: analytics.average(:average_order_value_cents).to_f / 100.0,
      avg_conversion_rate: analytics.average(:conversion_rate).to_f,
      total_page_views: analytics.sum(:page_views),
      total_visitors: analytics.sum(:unique_visitors),
      avg_satisfaction: analytics.average(:customer_satisfaction_score).to_f,
      trend: calculate_trend(analytics)
    }
  end
  
  # Get top products
  def self.top_products(seller, limit = 10)
    seller.products
          .joins(:line_items)
          .select('products.*, SUM(line_items.quantity) as total_sold, SUM(line_items.total_cents) as total_revenue')
          .group('products.id')
          .order('total_revenue DESC')
          .limit(limit)
  end
  
  # Get sales by category
  def self.sales_by_category(seller, period = 30)
    seller.products
          .joins(:line_items)
          .joins('INNER JOIN orders ON line_items.order_id = orders.id')
          .where('orders.created_at > ?', period.days.ago)
          .group('products.category')
          .select('products.category, SUM(line_items.total_cents) as revenue, SUM(line_items.quantity) as units')
          .order('revenue DESC')
  end
  
  # Get customer demographics
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
  
  private
  
  def self.calculate_conversion_rate(seller, date)
    views = calculate_page_views(seller, date)
    orders = seller.orders.where('DATE(created_at) = ?', date).count
    
    return 0 if views.zero?
    (orders.to_f / views * 100).round(2)
  end
  
  def self.calculate_page_views(seller, date)
    # This would integrate with analytics service
    rand(100..1000)
  end
  
  def self.calculate_unique_visitors(seller, date)
    # This would integrate with analytics service
    rand(50..500)
  end
  
  def self.calculate_cart_additions(seller, date)
    # This would track cart additions
    rand(20..200)
  end
  
  def self.calculate_revenue_per_visitor(seller, date)
    visitors = calculate_unique_visitors(seller, date)
    return 0 if visitors.zero?
    
    revenue = seller.orders.where('DATE(created_at) = ?', date).sum(:total_cents)
    (revenue / visitors).to_i
  end
  
  def self.calculate_return_rate(seller, date)
    # This would calculate return rate
    rand(0..5)
  end
  
  def self.calculate_satisfaction_score(seller, date)
    # This would calculate from reviews
    rand(4.0..5.0).round(2)
  end
  
  def self.calculate_trend(analytics)
    return 'stable' if analytics.count < 7
    
    recent = analytics.limit(7).average(:total_sales_cents).to_f
    previous = analytics.offset(7).limit(7).average(:total_sales_cents).to_f
    
    return 'stable' if previous.zero?
    
    change = ((recent - previous) / previous * 100).round(2)
    
    if change > 10
      'growing'
    elsif change < -10
      'declining'
    else
      'stable'
    end
  end
end

