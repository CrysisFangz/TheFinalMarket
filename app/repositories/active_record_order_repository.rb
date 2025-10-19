# frozen_string_literal: true

require_relative 'financial_repository'

# ActiveRecord implementation for Order data access
# Provides optimized queries for order volume calculations
class ActiveRecordOrderRepository < FinancialRepository::OrderRepository

  # Calculate total volume from completed orders
  # Optimized for large datasets with proper database indexing
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Integer] Total volume in cents
  def total_volume(start_date: nil, end_date: nil)
    query = Order.where(status: 'completed')

    if start_date.present?
      query = query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      query = query.where('created_at <= ?', end_date)
    end

    # Use database-level aggregation for optimal performance
    query.pick(Arel.sql('COALESCE(SUM(total_amount_cents), 0)')) || 0
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Order volume query failed: #{e.message}")
    0
  end

  # Get completed order count for additional metrics
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Integer] Completed order count
  def completed_count(start_date: nil, end_date: nil)
    query = Order.where(status: 'completed')

    if start_date.present?
      query = query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      query = query.where('created_at <= ?', end_date)
    end

    query.count
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Order count query failed: #{e.message}")
    0
  end

  # Batch load order metrics
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Hash] Order volume and count data
  def batch_load_metrics(start_date: nil, end_date: nil)
    query = Order.where(status: 'completed')

    if start_date.present?
      query = query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      query = query.where('created_at <= ?', end_date)
    end

    # Single query for both metrics
    results = query.pick(
      Arel.sql('COALESCE(SUM(total_amount_cents), 0) as total_volume'),
      Arel.sql('COUNT(*) as order_count')
    )

    {
      total_volume: results['total_volume'] || 0,
      completed_count: results['order_count'] || 0
    }
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Order batch load failed: #{e.message}")
    { total_volume: 0, completed_count: 0 }
  end
end