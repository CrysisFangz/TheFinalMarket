module AnalyticsEngine
  class ProductReport < BaseReport
    def generate_data
      {
        top_products: top_selling_products,
        product_performance: product_performance_metrics,
        inventory_turnover: inventory_turnover_data,
        product_trends: product_trend_analysis,
        category_performance: category_performance_data
      }
    end
    
    def generate_summary
      {
        total_products: total_products_count,
        products_sold: products_sold_count,
        avg_product_rating: average_product_rating,
        best_seller: best_selling_product,
        fastest_growing: fastest_growing_product
      }
    end
    
    def generate_visualizations
      [
        {
          type: 'bar_chart',
          title: 'Top Selling Products',
          data: top_selling_products.first(10)
        },
        {
          type: 'line_chart',
          title: 'Product Sales Trends',
          data: product_trend_analysis
        },
        {
          type: 'pie_chart',
          title: 'Category Performance',
          data: category_performance_data
        }
      ]
    end
    
    private
    
    def total_products_count
      Product.count
    end
    
    def products_sold_count
      LineItem.joins(:order)
              .where(orders: { created_at: date_range, status: 'completed' })
              .distinct
              .count(:product_id)
    end
    
    def average_product_rating
      Review.average(:rating)&.round(2) || 0
    end
    
    def best_selling_product
      product = LineItem.joins(:order, :product)
                       .where(orders: { created_at: date_range, status: 'completed' })
                       .group('products.id', 'products.name')
                       .select('products.name, SUM(line_items.quantity) as total_quantity')
                       .order('total_quantity DESC')
                       .first
      
      product&.name || 'N/A'
    end
    
    def fastest_growing_product
      # Compare current period to previous period
      current_sales = LineItem.joins(:order, :product)
                             .where(orders: { created_at: date_range, status: 'completed' })
                             .group('products.id', 'products.name')
                             .sum(:quantity)
      
      days = (date_range.end - date_range.begin).to_i
      previous_range = (date_range.begin - days.days)..(date_range.begin - 1.day)
      
      previous_sales = LineItem.joins(:order, :product)
                              .where(orders: { created_at: previous_range, status: 'completed' })
                              .group('products.id', 'products.name')
                              .sum(:quantity)
      
      growth_rates = {}
      current_sales.each do |product_id, current_qty|
        previous_qty = previous_sales[product_id] || 0
        next if previous_qty.zero?
        
        growth_rate = ((current_qty - previous_qty).to_f / previous_qty * 100).round(2)
        product_name = Product.find(product_id).name
        growth_rates[product_name] = growth_rate
      end
      
      growth_rates.max_by { |_, rate| rate }&.first || 'N/A'
    end
    
    def top_selling_products
      LineItem.joins(:order, :product)
              .where(orders: { created_at: date_range, status: 'completed' })
              .group('products.id', 'products.name')
              .select('products.name, SUM(line_items.quantity) as total_quantity')
              .order('total_quantity DESC')
              .limit(20)
              .map { |item| [item.name, item.total_quantity] }
              .to_h
    end
    
    def product_performance_metrics
      products = Product.joins(line_items: :order)
                       .where(orders: { created_at: date_range, status: 'completed' })
                       .group('products.id', 'products.name')
                       .select(
                         'products.name',
                         'SUM(line_items.quantity) as units_sold',
                         'SUM(line_items.price_cents * line_items.quantity) as revenue',
                         'AVG(line_items.price_cents) as avg_price'
                       )
                       .order('revenue DESC')
                       .limit(50)
      
      products.map do |p|
        {
          name: p.name,
          units_sold: p.units_sold,
          revenue: (p.revenue / 100.0).round(2),
          avg_price: (p.avg_price / 100.0).round(2)
        }
      end
    end
    
    def inventory_turnover_data
      # Inventory turnover = Cost of Goods Sold / Average Inventory
      products = Product.joins(line_items: :order)
                       .where(orders: { created_at: date_range, status: 'completed' })
                       .group('products.id', 'products.name', 'products.stock_quantity')
                       .select(
                         'products.name',
                         'products.stock_quantity',
                         'SUM(line_items.quantity) as units_sold'
                       )
                       .having('products.stock_quantity > 0')
      
      products.map do |p|
        turnover_rate = (p.units_sold.to_f / p.stock_quantity).round(2)
        {
          name: p.name,
          stock_quantity: p.stock_quantity,
          units_sold: p.units_sold,
          turnover_rate: turnover_rate,
          status: turnover_status(turnover_rate)
        }
      end.sort_by { |p| -p[:turnover_rate] }.first(20)
    end
    
    def turnover_status(rate)
      if rate > 2.0
        'High'
      elsif rate > 1.0
        'Good'
      elsif rate > 0.5
        'Moderate'
      else
        'Low'
      end
    end
    
    def product_trend_analysis
      # Daily sales for top 5 products
      top_5_products = LineItem.joins(:order, :product)
                              .where(orders: { created_at: date_range, status: 'completed' })
                              .group('products.id')
                              .sum(:quantity)
                              .sort_by { |_, qty| -qty }
                              .first(5)
                              .map(&:first)
      
      trends = {}
      
      top_5_products.each do |product_id|
        product = Product.find(product_id)
        daily_sales = LineItem.joins(:order)
                             .where(product_id: product_id)
                             .where(orders: { created_at: date_range, status: 'completed' })
                             .group_by_day('orders.created_at')
                             .sum(:quantity)
        
        trends[product.name] = daily_sales
      end
      
      trends
    end
    
    def category_performance_data
      Category.joins(products: { line_items: :order })
              .where(orders: { created_at: date_range, status: 'completed' })
              .group('categories.id', 'categories.name')
              .select(
                'categories.name',
                'SUM(line_items.price_cents * line_items.quantity) as revenue'
              )
              .order('revenue DESC')
              .map { |c| [c.name, (c.revenue / 100.0).round(2)] }
              .to_h
    end
  end
end

