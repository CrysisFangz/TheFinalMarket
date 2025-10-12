module AnalyticsEngine
  class SalesReport < BaseReport
    def generate_data
      {
        daily_sales: daily_sales_data,
        sales_by_channel: sales_by_channel_data,
        sales_by_region: sales_by_region_data,
        sales_funnel: sales_funnel_data,
        conversion_metrics: conversion_metrics_data
      }
    end
    
    def generate_summary
      orders = Order.where(created_at: date_range, status: 'completed')
      
      {
        total_sales: orders.count,
        total_revenue: format_currency(orders.sum(:total_cents)),
        avg_order_value: format_currency(orders.average(:total_cents) || 0),
        conversion_rate: format_percentage(calculate_conversion_rate),
        sales_growth: calculate_sales_growth
      }
    end
    
    def generate_visualizations
      [
        {
          type: 'line_chart',
          title: 'Daily Sales',
          data: daily_sales_data
        },
        {
          type: 'funnel_chart',
          title: 'Sales Funnel',
          data: sales_funnel_data
        },
        {
          type: 'bar_chart',
          title: 'Sales by Region',
          data: sales_by_region_data
        }
      ]
    end
    
    private
    
    def daily_sales_data
      Order.where(created_at: date_range, status: 'completed')
           .group_by_day(:created_at)
           .count
    end
    
    def sales_by_channel_data
      # Assuming we have a channel field or can infer from source
      {
        'Direct' => Order.where(created_at: date_range, status: 'completed').count,
        'Organic Search' => 0, # Would need tracking
        'Paid Ads' => 0,
        'Social Media' => 0,
        'Email' => 0
      }
    end
    
    def sales_by_region_data
      Order.where(created_at: date_range, status: 'completed')
           .joins(:shipping_address)
           .group('addresses.state')
           .count
           .sort_by { |_, count| -count }
           .first(10)
           .to_h
    end
    
    def sales_funnel_data
      # Track conversion through the funnel
      total_visitors = 10000 # Would need analytics integration
      product_views = 5000
      add_to_carts = Cart.where(created_at: date_range).distinct.count(:user_id)
      checkouts = Order.where(created_at: date_range).count
      completed = Order.where(created_at: date_range, status: 'completed').count
      
      {
        'Visitors' => total_visitors,
        'Product Views' => product_views,
        'Add to Cart' => add_to_carts,
        'Checkout' => checkouts,
        'Completed' => completed
      }
    end
    
    def conversion_metrics_data
      total_sessions = 10000 # Would need analytics integration
      completed_orders = Order.where(created_at: date_range, status: 'completed').count
      
      {
        overall_conversion_rate: (completed_orders.to_f / total_sessions * 100).round(2),
        cart_abandonment_rate: calculate_cart_abandonment_rate,
        checkout_abandonment_rate: calculate_checkout_abandonment_rate,
        avg_time_to_purchase: calculate_avg_time_to_purchase
      }
    end
    
    def calculate_conversion_rate
      total_sessions = 10000 # Would need analytics integration
      completed_orders = Order.where(created_at: date_range, status: 'completed').count
      
      (completed_orders.to_f / total_sessions * 100).round(2)
    end
    
    def calculate_sales_growth
      current_sales = Order.where(created_at: date_range, status: 'completed').count
      days = (date_range.end - date_range.begin).to_i
      previous_range = (date_range.begin - days.days)..(date_range.begin - 1.day)
      previous_sales = Order.where(created_at: previous_range, status: 'completed').count
      
      return format_percentage(0) if previous_sales.zero?
      
      growth = ((current_sales - previous_sales).to_f / previous_sales * 100).round(2)
      format_percentage(growth)
    end
    
    def calculate_cart_abandonment_rate
      carts_with_items = Cart.where(created_at: date_range)
                            .joins(:cart_items)
                            .distinct
                            .count
      
      completed_orders = Order.where(created_at: date_range, status: 'completed').count
      
      return 0 if carts_with_items.zero?
      
      abandoned = carts_with_items - completed_orders
      (abandoned.to_f / carts_with_items * 100).round(2)
    end
    
    def calculate_checkout_abandonment_rate
      checkouts = Order.where(created_at: date_range).count
      completed = Order.where(created_at: date_range, status: 'completed').count
      
      return 0 if checkouts.zero?
      
      abandoned = checkouts - completed
      (abandoned.to_f / checkouts * 100).round(2)
    end
    
    def calculate_avg_time_to_purchase
      # Average time from cart creation to order completion
      orders = Order.where(created_at: date_range, status: 'completed')
                   .joins(:user)
                   .includes(:user)
      
      times = []
      orders.each do |order|
        cart = Cart.find_by(user: order.user)
        next unless cart
        
        time_diff = (order.created_at - cart.created_at) / 3600.0 # in hours
        times << time_diff if time_diff > 0 && time_diff < 720 # exclude outliers > 30 days
      end
      
      return 0 if times.empty?
      
      (times.sum / times.count).round(2)
    end
  end
end

