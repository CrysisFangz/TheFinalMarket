class SalesChannelAnalyticsService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'sales_channel_analytics'
  CACHE_TTL = 10.minutes

  def self.get_performance_metrics(channel, start_date: 30.days.ago, end_date: Time.current)
    cache_key = "#{CACHE_KEY_PREFIX}:performance:#{channel.id}:#{start_date.to_i}:#{end_date.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('sales_channel_analytics') do
        with_retry do
          performance_service = SalesChannelPerformanceService.new(channel)
          metrics = performance_service.performance_metrics(start_date: start_date, end_date: end_date)

          EventPublisher.publish('sales_channel.performance_metrics_retrieved', {
            channel_id: channel.id,
            channel_type: channel.channel_type,
            name: channel.name,
            start_date: start_date,
            end_date: end_date,
            metrics_count: metrics.keys.count
          })

          metrics
        end
      end
    end
  end

  def self.get_channel_statistics(channel)
    cache_key = "#{CACHE_KEY_PREFIX}:statistics:#{channel.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('sales_channel_analytics') do
        with_retry do
          analytics_service = SalesChannelAnalyticsService.new(channel)
          stats = analytics_service.statistics

          EventPublisher.publish('sales_channel.statistics_retrieved', {
            channel_id: channel.id,
            channel_type: channel.channel_type,
            name: channel.name,
            stats_count: stats.keys.count
          })

          stats
        end
      end
    end
  end

  def self.perform_health_check(channel)
    cache_key = "#{CACHE_KEY_PREFIX}:health_check:#{channel.id}"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      with_circuit_breaker('sales_channel_analytics') do
        with_retry do
          analytics_service = SalesChannelAnalyticsService.new(channel)
          health_check = analytics_service.health_check

          EventPublisher.publish('sales_channel.health_check_performed', {
            channel_id: channel.id,
            channel_type: channel.channel_type,
            name: channel.name,
            status: health_check[:status],
            response_time: health_check[:response_time],
            error_rate: health_check[:error_rate]
          })

          health_check
        end
      end
    end
  end

  def self.get_channel_revenue(channel, start_date: 30.days.ago, end_date: Time.current)
    cache_key = "#{CACHE_KEY_PREFIX}:revenue:#{channel.id}:#{start_date.to_i}:#{end_date.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('sales_channel_analytics') do
        with_retry do
          orders = channel.orders.where(created_at: start_date..end_date)
          revenue = orders.sum(:total)

          EventPublisher.publish('sales_channel.revenue_calculated', {
            channel_id: channel.id,
            channel_type: channel.channel_type,
            name: channel.name,
            start_date: start_date,
            end_date: end_date,
            order_count: orders.count,
            total_revenue: revenue
          })

          {
            total_revenue: revenue,
            order_count: orders.count,
            average_order_value: orders.count > 0 ? revenue / orders.count : 0,
            currency: 'USD'
          }
        end
      end
    end
  end

  def self.get_channel_conversion_rate(channel, start_date: 30.days.ago, end_date: Time.current)
    cache_key = "#{CACHE_KEY_PREFIX}:conversion:#{channel.id}:#{start_date.to_i}:#{end_date.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('sales_channel_analytics') do
        with_retry do
          # Get views/visits for the channel
          views = channel.channel_analytics.where(created_at: start_date..end_date).sum(:views)
          orders = channel.orders.where(created_at: start_date..end_date).count

          conversion_rate = views > 0 ? (orders.to_f / views) * 100 : 0

          EventPublisher.publish('sales_channel.conversion_calculated', {
            channel_id: channel.id,
            channel_type: channel.channel_type,
            name: channel.name,
            start_date: start_date,
            end_date: end_date,
            views: views,
            orders: orders,
            conversion_rate: conversion_rate
          })

          {
            views: views,
            orders: orders,
            conversion_rate: conversion_rate,
            period: "#{start_date} to #{end_date}"
          }
        end
      end
    end
  end

  def self.get_top_performing_products(channel, limit: 10, start_date: 30.days.ago, end_date: Time.current)
    cache_key = "#{CACHE_KEY_PREFIX}:top_products:#{channel.id}:#{limit}:#{start_date.to_i}:#{end_date.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('sales_channel_analytics') do
        with_retry do
          top_products = channel.orders
                               .joins(:products)
                               .where(created_at: start_date..end_date)
                               .group('products.id')
                               .order('SUM(order_items.quantity) DESC')
                               .limit(limit)
                               .includes(:products)
                               .map do |order|
                                 product = order.products.first
                                 {
                                   product_id: product.id,
                                   product_name: product.name,
                                   quantity_sold: order.order_items.sum(:quantity),
                                   revenue: order.order_items.sum('quantity * price')
                                 }
                               end

          EventPublisher.publish('sales_channel.top_products_retrieved', {
            channel_id: channel.id,
            channel_type: channel.channel_type,
            name: channel.name,
            limit: limit,
            start_date: start_date,
            end_date: end_date,
            top_products_count: top_products.count
          })

          top_products
        end
      end
    end
  end

  def self.clear_analytics_cache(channel_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:performance:#{channel_id}",
      "#{CACHE_KEY_PREFIX}:statistics:#{channel_id}",
      "#{CACHE_KEY_PREFIX}:health_check:#{channel_id}",
      "#{CACHE_KEY_PREFIX}:revenue:#{channel_id}",
      "#{CACHE_KEY_PREFIX}:conversion:#{channel_id}",
      "#{CACHE_KEY_PREFIX}:top_products:#{channel_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end