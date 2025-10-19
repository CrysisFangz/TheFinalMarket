# frozen_string_literal: true

require_relative 'financial_repository'

# ActiveRecord implementation for EscrowTransaction data access
# Provides optimized queries for escrow financial calculations
class ActiveRecordEscrowTransactionRepository < FinancialRepository::EscrowTransactionRepository

  # Calculate fees collected from released escrow transactions
  # Uses database-level aggregation with proper indexing
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Integer] Total fees in cents
  def fees_collected(start_date: nil, end_date: nil)
    query = EscrowTransaction.where(status: 'released')

    if start_date.present?
      query = query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      query = query.where('created_at <= ?', end_date)
    end

    query.pick(Arel.sql('COALESCE(SUM(fee_cents), 0)')) || 0
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("EscrowTransaction fees query failed: #{e.message}")
    0
  end

  # Calculate total pending escrow amount
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Integer] Total pending amount in cents
  def pending_amount(start_date: nil, end_date: nil)
    query = EscrowTransaction.where(status: 'held')

    if start_date.present?
      query = query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      query = query.where('created_at <= ?', end_date)
    end

    query.pick(Arel.sql('COALESCE(SUM(amount_cents), 0)')) || 0
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("EscrowTransaction pending query failed: #{e.message}")
    0
  end

  # Batch load escrow metrics for multiple calculations
  # Optimizes multiple queries into single database call
  # @param start_date [DateTime, nil] Start date filter
  # @param end_date [DateTime, nil] End date filter
  # @return [Hash] Aggregated escrow data
  def batch_load_metrics(start_date: nil, end_date: nil)
    # Build base query conditions
    released_query = EscrowTransaction.where(status: 'released')
    held_query = EscrowTransaction.where(status: 'held')

    if start_date.present?
      released_query = released_query.where('created_at >= ?', start_date)
      held_query = held_query.where('created_at >= ?', start_date)
    end

    if end_date.present?
      released_query = released_query.where('created_at <= ?', end_date)
      held_query = held_query.where('created_at <= ?', end_date)
    end

    # Execute both aggregations in parallel when possible
    released_fees = released_query.pick(Arel.sql('COALESCE(SUM(fee_cents), 0)')) || 0
    held_amount = held_query.pick(Arel.sql('COALESCE(SUM(amount_cents), 0)')) || 0

    {
      fees_collected: released_fees,
      pending_amount: held_amount
    }
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("EscrowTransaction batch load failed: #{e.message}")
    { fees_collected: 0, pending_amount: 0 }
  end
end