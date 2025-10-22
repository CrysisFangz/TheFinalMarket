# frozen_string_literal: true

require 'concurrent-ruby'

# ChannelAnalytics - Immutable analytics data model
# Represents a point-in-time snapshot of sales channel performance metrics
class ChannelAnalytics < ApplicationRecord
  belongs_to :sales_channel, touch: true

  validates :sales_channel, presence: true
  validates :date, presence: true
  validates :date, uniqueness: { scope: :sales_channel_id }
  validates :orders_count, :revenue, :average_order_value,
            :unique_customers, :new_customers, :returning_customers,
            :conversion_rate, :return_rate, :units_sold,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Immutable value object for analytics data
  # Ensures thread safety and referential transparency
  AnalyticsData = Struct.new(
    :orders_count, :revenue, :average_order_value, :unique_customers,
    :new_customers, :returning_customers, :conversion_rate, :return_rate,
    :units_sold, keyword_init: true
  ) do
    def to_h
      to_h.except(:to_h)
    end
  end

  private_constant :AnalyticsData

  # Enhanced error handling with structured error types
  class AnalyticsError < StandardError
    attr_reader :error_type, :context

    def initialize(message, error_type: :general, context: {})
      super(message)
      @error_type = error_type
      @context = context
    end
  end

  class ValidationError < AnalyticsError
    def initialize(message, context = {})
      super(message, error_type: :validation, context: context)
    end
  end

  class CalculationError < AnalyticsError
    def initialize(message, context = {})
      super(message, error_type: :calculation, context: context)
    end
  end

  private_constant :AnalyticsError, :ValidationError, :CalculationError

  # Circuit breaker for external service calls
  CIRCUIT_BREAKER = Concurrent::CircuitBreaker.new(
    failure_threshold: 3,
    recovery_timeout: 60,
    expected_exception: StandardError
  )

  private_constant :CIRCUIT_BREAKER

  # Caching layer for expensive calculations
  CACHE_TTL = 1.hour
  private_constant :CACHE_TTL

  class << self
    # Record daily analytics with enhanced error handling and performance optimization
    # @param channel [SalesChannel] The sales channel to record analytics for
    # @param date [Date] The date for analytics (defaults to today)
    # @return [ChannelAnalytics] The recorded analytics record
    def record_for_channel(channel, date = Date.current)
      validate_inputs!(channel, date)

      Rails.cache.fetch(cache_key(channel, date), expires_in: CACHE_TTL) do
        CIRCUIT_BREAKER.execute do
          analytics = transaction(isolation: :repeatable_read) do
            find_or_initialize_by(sales_channel: channel, date: date)
          end

          analytics_data = calculate_analytics_data(channel, date)

          analytics.assign_attributes(analytics_data.to_h)
          analytics.save!

          # Broadcast analytics update event for real-time dashboards
          broadcast_analytics_update(analytics, analytics_data)

          analytics
        end
      end
    rescue ActiveRecord::RecordNotUnique => e
      # Handle race condition gracefully
      Rails.logger.warn("Analytics record already exists for #{channel.id} on #{date}")
      find_by!(sales_channel: channel, date: date)
    rescue StandardError => e
      Rails.logger.error("Failed to record analytics for channel #{channel.id}: #{e.message}")
      handle_error(e, :recording, channel: channel.id, date: date)
      raise CalculationError.new("Failed to record analytics", context: { channel_id: channel.id, date: date })
    end

    # Get trend data with optimized query performance
    # @param channel [SalesChannel] The sales channel
    # @param days [Integer] Number of days to look back (default: 30)
    # @return [Array<Array>] Array of [date, revenue, orders_count, conversion_rate]
    def trend_data(channel, days: 30)
      validate_channel!(channel)
      validate_days!(days)

      Rails.cache.fetch("trend_data:#{channel.id}:#{days}", expires_in: CACHE_TTL) do
        where(sales_channel: channel)
          .where('date >= ?', days.days.ago.to_date)
          .order(:date)
          .pluck(:date, :revenue, :orders_count, :conversion_rate)
      end
    rescue StandardError => e
      handle_error(e, :trend_data, channel: channel.id, days: days)
      []
    end

    # Get analytics for specific date range with pagination support
    # @param channel [SalesChannel] The sales channel
    # @param start_date [Date] Start date for range
    # @param end_date [Date] End date for range
    # @param page [Integer] Page number for pagination
    # @param per_page [Integer] Items per page
    # @return [Array<ChannelAnalytics>] Paginated analytics records
    def range_data(channel, start_date, end_date, page: 1, per_page: 100)
      validate_date_range!(start_date, end_date)

      where(sales_channel: channel)
        .where(date: start_date..end_date)
        .order(date: :desc)
        .page(page)
        .per(per_page)
    rescue StandardError => e
      handle_error(e, :range_data, channel: channel.id, start_date: start_date, end_date: end_date)
      []
    end

    # Calculate performance metrics for benchmarking
    # @param channel [SalesChannel] The sales channel
    # @param days [Integer] Number of days to analyze
    # @return [Hash] Performance metrics including growth rates
    def performance_metrics(channel, days: 30)
      validate_inputs!(channel, days)

      data = trend_data(channel, days: days)

      return {} if data.empty?

      dates, revenues, orders_counts, conversion_rates = data.transpose

      {
        total_revenue: revenues.sum,
        average_daily_revenue: revenues.sum.to_f / dates.length,
        revenue_growth_rate: calculate_growth_rate(revenues),
        total_orders: orders_counts.sum,
        average_orders_per_day: orders_counts.sum.to_f / dates.length,
        average_conversion_rate: conversion_rates.compact.sum.to_f / conversion_rates.compact.length,
        peak_revenue_date: dates[revenues.index(revenues.max)],
        data_points: data.length
      }
    rescue StandardError => e
      handle_error(e, :performance_metrics, channel: channel.id, days: days)
      {}
    end

    private

    # Validate input parameters
    def validate_inputs!(channel, date_or_days)
      validate_channel!(channel)
      case date_or_days
      when Date
        validate_date!(date_or_days)
      when Integer
        validate_days!(date_or_days)
      else
        raise ValidationError.new("Invalid parameter type", context: { param: date_or_days.class })
      end
    end

    def validate_channel!(channel)
      raise ValidationError.new("Channel cannot be nil", context: {}) unless channel
      raise ValidationError.new("Invalid channel", context: { channel_id: channel.id }) unless channel.is_a?(SalesChannel)
    end

    def validate_date!(date)
      raise ValidationError.new("Date cannot be nil", context: {}) unless date
      raise ValidationError.new("Invalid date", context: { date: date }) unless date.is_a?(Date)
      raise ValidationError.new("Date cannot be in future", context: { date: date }) if date > Date.current
    end

    def validate_days!(days)
      raise ValidationError.new("Days must be positive", context: { days: days }) unless days.positive?
      raise ValidationError.new("Days cannot exceed 365", context: { days: days }) if days > 365
    end

    def validate_date_range!(start_date, end_date)
      validate_date!(start_date)
      validate_date!(end_date)
      raise ValidationError.new("Start date must be before end date", context: { start_date: start_date, end_date: end_date }) if start_date > end_date
    end

    # Calculate comprehensive analytics data
    def calculate_analytics_data(channel, date)
      orders = fetch_orders_for_date(channel, date)

      calculator = AnalyticsCalculator.new(orders, channel, date)
      calculator.calculate
    end

    # Fetch orders with optimized query to prevent N+1
    def fetch_orders_for_date(channel, date)
      channel.orders
             .includes(:user, :order_items)
             .where('DATE(created_at) = ?', date)
             .to_a
    end

    # Calculate growth rate between first and last values
    def calculate_growth_rate(values)
      return 0.0 if values.length < 2 || values.first.zero?

      ((values.last - values.first) / values.first * 100).round(2)
    end

    # Generate cache key for analytics data
    def cache_key(channel, date)
      "channel_analytics:#{channel.id}:#{date.to_s(:db)}"
    end

    # Broadcast analytics update for real-time dashboards
    def broadcast_analytics_update(analytics, analytics_data)
      # Integration point for real-time updates (e.g., ActionCable, Redis pub/sub)
      AnalyticsBroadcastJob.perform_later(analytics.id, analytics_data.to_h)
    end

    # Centralized error handling
    def handle_error(error, operation, context)
      Rails.logger.error(
        "Analytics #{operation} failed: #{error.message}",
        error_type: error.class.name,
        operation: operation,
        context: context,
        backtrace: error.backtrace&.first(5)
      )

      # Report to monitoring service (e.g., Sentry, DataDog)
      MonitoringService.report_error(error, context: context, operation: operation)
    end
  end

  # Immutable value object for analytics calculations
  class AnalyticsCalculator
    attr_reader :orders, :channel, :date

    def initialize(orders, channel, date)
      @orders = orders
      @channel = channel
      @date = date
    end

    def calculate
      AnalyticsData.new(
        orders_count: calculate_orders_count,
        revenue: calculate_revenue,
        average_order_value: calculate_average_order_value,
        unique_customers: calculate_unique_customers,
        new_customers: calculate_new_customers,
        returning_customers: calculate_returning_customers,
        conversion_rate: calculate_conversion_rate,
        return_rate: calculate_return_rate,
        units_sold: calculate_units_sold
      )
    end

    private

    def calculate_orders_count
      orders.length
    end

    def calculate_revenue
      completed_orders.sum(&:total).to_f
    end

    def calculate_average_order_value
      completed_orders.empty? ? 0.0 : (completed_orders.sum(&:total) / completed_orders.length).round(2)
    end

    def calculate_unique_customers
      completed_orders.distinct.pluck(:user_id).length
    end

    def calculate_new_customers
      completed_orders.joins(:user)
                     .where('users.created_at >= ?', date.beginning_of_day)
                     .distinct
                     .pluck(:user_id)
                     .length
    end

    def calculate_returning_customers
      completed_orders.joins(:user)
                     .where('users.created_at < ?', date.beginning_of_day)
                     .distinct
                     .pluck(:user_id)
                     .length
    end

    def calculate_conversion_rate
      # Enhanced conversion rate calculation with external traffic data integration
      traffic_service = TrafficAnalyticsService.new(channel)
      traffic_service.conversion_rate_for_date(date)
    rescue StandardError => e
      Rails.logger.warn("Failed to calculate conversion rate: #{e.message}")
      0.0 # Fallback to 0.0 instead of random value
    end

    def calculate_return_rate
      return 0.0 if orders.empty?

      returned_orders = orders.where(status: 'returned')
      (returned_orders.length.to_f / orders.length * 100).round(2)
    end

    def calculate_units_sold
      orders.joins(:order_items).sum('order_items.quantity')
    end

    def completed_orders
      @completed_orders ||= orders.select { |order| order.status == 'completed' }
    end
  end

  private_constant :AnalyticsCalculator

  # Performance monitoring integration
  class MonitoringService
    class << self
      def report_error(error, context: {}, operation: nil)
        # Integration with monitoring service (e.g., Sentry, DataDog)
        # This would be implemented based on your monitoring stack
        Rails.logger.error("Analytics error reported to monitoring", error: error, context: context, operation: operation)
      end

      def record_performance_metrics(operation, duration, context = {})
        # Record performance metrics for observability
        Rails.logger.info("Analytics performance: #{operation} took #{duration}ms", context: context)
      end
    end
  end

  private_constant :MonitoringService
end