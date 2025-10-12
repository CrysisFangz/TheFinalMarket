module AnalyticsEngine
  class RevenueReport < BaseReport
    def generate_data
      {
        daily_revenue: daily_revenue_data,
        revenue_by_category: revenue_by_category_data,
        revenue_by_product: top_products_by_revenue,
        revenue_trends: revenue_trends_data
      }
    end
    
    def generate_summary
      orders = Order.where(created_at: date_range, status: 'completed')
      
      {
        total_revenue: format_currency(orders.sum(:total_cents)),
        total_orders: orders.count,
        average_order_value: format_currency(orders.average(:total_cents) || 0),
        revenue_growth: calculate_revenue_growth
      }
    end
    
    def generate_visualizations
      [
        {
          type: 'line_chart',
          title: 'Daily Revenue',
          data: daily_revenue_data
        },
        {
          type: 'pie_chart',
          title: 'Revenue by Category',
          data: revenue_by_category_data
        },
        {
          type: 'bar_chart',
          title: 'Top Products by Revenue',
          data: top_products_by_revenue.first(10)
        }
      ]
    end
    
    private
    
    def daily_revenue_data
      Order.where(created_at: date_range, status: 'completed')
           .group_by_day(:created_at)
           .sum(:total_cents)
           .transform_values { |v| (v / 100.0).round(2) }
    end
    
    def revenue_by_category_data
      Order.where(created_at: date_range, status: 'completed')
           .joins(line_items: { product: :categories })
           .group('categories.name')
           .sum('line_items.price_cents * line_items.quantity')
           .transform_values { |v| (v / 100.0).round(2) }
    end
    
    def top_products_by_revenue
      LineItem.joins(:order, :product)
              .where(orders: { created_at: date_range, status: 'completed' })
              .group('products.id', 'products.name')
              .select('products.name, SUM(line_items.price_cents * line_items.quantity) as revenue')
              .order('revenue DESC')
              .limit(20)
              .map { |item| [item.name, (item.revenue / 100.0).round(2)] }
              .to_h
    end
    
    def revenue_trends_data
      current_period = Order.where(created_at: date_range, status: 'completed').sum(:total_cents)
      days = (date_range.end - date_range.begin).to_i
      previous_period = Order.where(created_at: (date_range.begin - days.days)..(date_range.begin - 1.day), status: 'completed').sum(:total_cents)
      
      {
        current_period: (current_period / 100.0).round(2),
        previous_period: (previous_period / 100.0).round(2),
        growth_rate: previous_period > 0 ? (((current_period - previous_period) / previous_period.to_f) * 100).round(2) : 0
      }
    end
    
    def calculate_revenue_growth
      trends = revenue_trends_data
      format_percentage(trends[:growth_rate])
    end
  end
end

