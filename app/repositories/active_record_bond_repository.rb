# frozen_string_literal: true

require_relative 'financial_repository'

# ActiveRecord implementation for Bond data access
# Provides optimized queries for bond financial calculations
class ActiveRecordBondRepository < FinancialRepository::BondRepository

  # Calculate total active bonds amount
  # Optimized for bond portfolio calculations
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Integer] Total active amount in cents
  def active_amount(start_date: nil, end_date: nil)
    query = Bond.where(status: 'active')

    if start_date.present?
      query = query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      query = query.where('created_at <= ?', end_date)
    end

    # Use database aggregation for performance
    query.pick(Arel.sql('COALESCE(SUM(amount_cents), 0)')) || 0
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Bond active amount query failed: #{e.message}")
    0
  end

  # Get active bond count for portfolio metrics
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Integer] Active bond count
  def active_count(start_date: nil, end_date: nil)
    query = Bond.where(status: 'active')

    if start_date.present?
      query = query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      query = query.where('created_at <= ?', end_date)
    end

    query.count
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Bond count query failed: #{e.message}")
    0
  end

  # Batch load bond metrics for multiple calculations
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Hash] Bond amount and count data
  def batch_load_metrics(start_date: nil, end_date: nil)
    query = Bond.where(status: 'active')

    if start_date.present?
      query = query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      query = query.where('created_at <= ?', end_date)
    end

    # Single optimized query for both metrics
    results = query.pick(
      Arel.sql('COALESCE(SUM(amount_cents), 0) as total_amount'),
      Arel.sql('COUNT(*) as bond_count')
    )

    {
      active_amount: results['total_amount'] || 0,
      active_count: results['bond_count'] || 0
    }
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Bond batch load failed: #{e.message}")
    { active_amount: 0, active_count: 0 }
  end

  # Get bond portfolio statistics
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Hash] Comprehensive bond portfolio data
  def portfolio_stats(start_date: nil, end_date: nil)
    query = Bond.where(status: 'active')

    if start_date.present?
      query = query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      query = query.where('created_at <= ?', end_date)
    end

    # Calculate multiple portfolio metrics in single query
    results = query.pick(
      Arel.sql('COUNT(*) as total_bonds'),
      Arel.sql('COALESCE(SUM(amount_cents), 0) as total_value'),
      Arel.sql('COALESCE(AVG(amount_cents), 0) as avg_bond_size'),
      Arel.sql('MIN(created_at) as oldest_bond_date'),
      Arel.sql('MAX(created_at) as newest_bond_date')
    )

    {
      total_bonds: results['total_bonds'] || 0,
      total_value: results['total_value'] || 0,
      average_bond_size: results['avg_bond_size'] || 0,
      oldest_bond_date: results['oldest_bond_date'],
      newest_bond_date: results['newest_bond_date']
    }
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Bond portfolio stats query failed: #{e.message}")
    {
      total_bonds: 0,
      total_value: 0,
      average_bond_size: 0,
      oldest_bond_date: nil,
      newest_bond_date: nil
    }
  end
end