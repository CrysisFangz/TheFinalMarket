# frozen_string_literal: true

require_relative 'financial_repository'

# ActiveRecord implementation for PaymentTransaction data access
# Provides optimized queries with proper indexing and caching support
class ActiveRecordPaymentTransactionRepository < FinancialRepository::PaymentTransactionRepository

  # Optimized query for total revenue calculation
  # Uses database-level aggregation for maximum performance
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Integer] Total amount in cents
  def total_revenue(start_date: nil, end_date: nil)
    query = PaymentTransaction.where(status: 'succeeded')

    if start_date.present?
      query = query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      query = query.where('created_at <= ?', end_date)
    end

    # Use select for single aggregation to minimize memory usage
    query.pick(Arel.sql('COALESCE(SUM(amount_cents), 0)')) || 0
  rescue ActiveRecord::StatementInvalid => e
    # Log the error and return 0 as safe fallback
    Rails.logger.error("PaymentTransaction revenue query failed: #{e.message}")
    0
  end

  # Optimized count query for successful transactions
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Integer] Transaction count
  def successful_count(start_date: nil, end_date: nil)
    query = PaymentTransaction.where(status: 'succeeded')

    if start_date.present?
      query = query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      query = query.where('created_at <= ?', end_date)
    end

    query.count
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("PaymentTransaction count query failed: #{e.message}")
    0
  end

  # Batch load payment transactions for multiple metrics
  # Optimizes N+1 queries by loading all required data in one query
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Hash] Aggregated payment data
  def batch_load_metrics(start_date: nil, end_date: nil)
    query = PaymentTransaction.where(status: 'succeeded')

    if start_date.present?
      query = query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      query = query.where('created_at <= ?', end_date)
    end

    # Single query to get both sum and count
    results = query.pick(
      Arel.sql('COALESCE(SUM(amount_cents), 0) as total_amount'),
      Arel.sql('COUNT(*) as transaction_count')
    )

    {
      total_revenue: results['total_amount'] || 0,
      successful_count: results['transaction_count'] || 0
    }
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("PaymentTransaction batch load failed: #{e.message}")
    { total_revenue: 0, successful_count: 0 }
  end
end