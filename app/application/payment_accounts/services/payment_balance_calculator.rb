# frozen_string_literal: true

# Enterprise Payment Balance Calculator
# High-performance balance calculation with caching and precision handling
class PaymentBalanceCalculator
  include ServiceResultHelper

  # Calculate available balance for a payment account
  def calculate_available_balance(payment_account)
    CircuitBreaker.execute_with_fallback(:balance_calculation) do
      ReactivePromise.new do |resolve, reject|
        begin
          # Execute parallel balance calculations
          results = execute_parallel_calculations(payment_account)

          # Aggregate results with precision
          balance = aggregate_balance_results(results)

          # Apply business rules and limits
          final_balance = apply_business_rules(payment_account, balance)

          resolve.call(success_result(final_balance, 'Balance calculated successfully'))
        rescue => e
          reject.call(failure_result("Balance calculation failed: #{e.message}"))
        end
      end
    end
  end

  # Calculate account balance with detailed breakdown
  def calculate_account_balance(payment_account)
    CircuitBreaker.execute_with_fallback(:detailed_balance_calculation) do
      # Get cached transaction totals
      cached_totals = Rails.cache.fetch("account_totals_#{payment_account.id}", expires_in: 10.minutes) do
        calculate_transaction_totals(payment_account)
      end

      # Calculate pending amounts
      pending_amounts = calculate_pending_amounts(payment_account)

      # Calculate reserved amounts (escrow, holds)
      reserved_amounts = calculate_reserved_amounts(payment_account)

      # Apply precision and rounding
      Money.new(
        (cached_totals[:completed] + pending_amounts[:available] - reserved_amounts[:total]).to_f * 100
      ).round_to_nearest_cent
    end
  end

  # Calculate balance projection for future date
  def calculate_balance_projection(payment_account, future_date)
    current_balance = calculate_account_balance(payment_account)

    # Get scheduled transactions
    scheduled_transactions = get_scheduled_transactions(payment_account, future_date)

    # Project balance changes
    projected_changes = calculate_projected_changes(scheduled_transactions)

    current_balance + projected_changes
  end

  private

  def execute_parallel_calculations(payment_account)
    calculations = [
      -> { calculate_completed_payments(payment_account) },
      -> { calculate_pending_payments(payment_account) },
      -> { calculate_escrow_holds(payment_account) },
      -> { calculate_reserved_funds(payment_account) }
    ]

    # Execute calculations in parallel using reactive streams
    ReactiveParallelExecutor.execute(calculations)
  end

  def aggregate_balance_results(results)
    completed = results[:completed_payments] || Money.new(0)
    pending = results[:pending_payments] || Money.new(0)
    holds = results[:escrow_holds] || Money.new(0)
    reserved = results[:reserved_funds] || Money.new(0)

    # Available balance = completed + pending - holds - reserved
    completed + pending - holds - reserved
  end

  def apply_business_rules(payment_account, balance)
    # Apply account-specific limits and rules
    rules_engine = PaymentRulesEngine.new(payment_account)

    # Apply velocity limits
    velocity_limited_balance = rules_engine.apply_velocity_limits(balance)

    # Apply risk-based limits
    risk_limited_balance = rules_engine.apply_risk_limits(velocity_limited_balance)

    # Apply regulatory limits
    rules_engine.apply_regulatory_limits(risk_limited_balance)
  end

  def calculate_transaction_totals(payment_account)
    completed_sql = build_completed_payments_sql(payment_account)
    pending_sql = build_pending_payments_sql(payment_account)

    {
      completed: execute_balance_query(completed_sql),
      pending: execute_balance_query(pending_sql)
    }
  end

  def calculate_pending_amounts(payment_account)
    # Calculate amounts from pending transactions
    pending_incoming = payment_account.incoming_transactions.pending.sum(:amount_cents)
    pending_outgoing = payment_account.outgoing_transactions.pending.sum(:amount_cents)

    {
      available: pending_incoming,
      pending_deduction: pending_outgoing
    }
  end

  def calculate_reserved_amounts(payment_account)
    # Calculate amounts in escrow and holds
    escrow_amount = payment_account.escrow_holds.active.sum(:amount_cents)
    reserve_amount = payment_account.payment_reserves.sum(:amount_cents)

    {
      escrow: escrow_amount,
      reserves: reserve_amount,
      total: escrow_amount + reserve_amount
    }
  end

  def get_scheduled_transactions(payment_account, future_date)
    # Get scheduled recurring payments, subscriptions, etc.
    payment_account.scheduled_transactions.where('scheduled_date <= ?', future_date)
  end

  def calculate_projected_changes(scheduled_transactions)
    scheduled_transactions.sum do |transaction|
      transaction.transaction_type == 'debit' ? -transaction.amount_cents : transaction.amount_cents
    end
  end

  def build_completed_payments_sql(payment_account)
    PaymentTransaction.where(source_account: payment_account, status: :completed).select(:amount_cents)
  end

  def build_pending_payments_sql(payment_account)
    PaymentTransaction.where(source_account: payment_account, status: :pending).select(:amount_cents)
  end

  def execute_balance_query(sql_query)
    # Use database-level aggregation for performance
    sql_query.sum(:amount_cents) || 0
  end
end