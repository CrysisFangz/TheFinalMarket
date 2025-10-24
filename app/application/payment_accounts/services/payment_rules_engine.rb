# frozen_string_literal: true

# Enterprise Payment Rules Engine
# Business rules enforcement with dynamic configuration and audit trails
class PaymentRulesEngine
  include ServiceResultHelper

  def initialize(payment_account)
    @payment_account = payment_account
    @rules_config = load_rules_configuration
  end

  # Apply velocity limits to balance
  def apply_velocity_limits(balance)
    CircuitBreaker.execute_with_fallback(:velocity_limits) do
      velocity_rules = @rules_config[:velocity_limits]
      account_velocity = calculate_current_velocity

      # Apply daily limit
      daily_limit = velocity_rules[:daily_limit] || Money.new(100000) # $1000 default
      if account_velocity[:daily] > daily_limit
        limited_balance = balance * (daily_limit / account_velocity[:daily])
        return limited_balance
      end

      # Apply monthly limit
      monthly_limit = velocity_rules[:monthly_limit] || Money.new(500000) # $5000 default
      if account_velocity[:monthly] > monthly_limit
        limited_balance = balance * (monthly_limit / account_velocity[:monthly])
        return limited_balance
      end

      balance
    end
  end

  # Apply risk-based limits to balance
  def apply_risk_limits(balance)
    CircuitBreaker.execute_with_fallback(:risk_limits) do
      risk_rules = @rules_config[:risk_limits]
      current_risk_level = @payment_account.risk_level

      # Apply risk-based multipliers
      risk_multipliers = risk_rules[:multipliers] || default_risk_multipliers
      risk_multiplier = risk_multipliers[current_risk_level.to_sym] || 1.0

      balance * risk_multiplier
    end
  end

  # Apply regulatory limits to balance
  def apply_regulatory_limits(balance)
    CircuitBreaker.execute_with_fallback(:regulatory_limits) do
      regulatory_rules = @rules_config[:regulatory_limits]

      # Apply KYC-based limits
      kyc_limit = regulatory_rules[:kyc_limits][@payment_account.kyc_status.to_sym] || balance
      limited_balance = [balance, kyc_limit].min

      # Apply geographic limits
      geo_limit = regulatory_rules[:geographic_limits][@payment_account.country.to_sym] || balance
      limited_balance = [limited_balance, geo_limit].min

      # Apply account age limits
      age_limit = calculate_age_based_limit(regulatory_rules[:age_limits])
      [limited_balance, age_limit].min
    end
  end

  # Validate transaction against business rules
  def validate_transaction(transaction_data)
    CircuitBreaker.execute_with_fallback(:transaction_validation) do
      validations = [
        -> { validate_amount_limits(transaction_data) },
        -> { validate_velocity_rules(transaction_data) },
        -> { validate_risk_rules(transaction_data) },
        -> { validate_regulatory_rules(transaction_data) },
        -> { validate_business_hours(transaction_data) }
      ]

      validation_results = validations.map(&:call)

      if validation_results.all?(&:success?)
        success_result(validation_results, 'Transaction validation passed')
      else
        failure_result('Transaction validation failed', validation_results)
      end
    end
  end

  private

  def load_rules_configuration
    Rails.cache.fetch('payment_rules_config', expires_in: 1.hour) do
      {
        velocity_limits: {
          daily_limit: Money.new(100000),    # $1000
          monthly_limit: Money.new(500000),  # $5000
          hourly_limit: Money.new(10000)     # $100
        },
        risk_limits: {
          multipliers: {
            low: 1.0,
            medium: 0.8,
            high: 0.5,
            critical: 0.2,
            extreme: 0.0
          }
        },
        regulatory_limits: {
          kyc_limits: {
            unverified: Money.new(10000),     # $100
            basic: Money.new(50000),         # $500
            verified: Money.new(1000000),    # $10,000
            enhanced: Money.new(10000000)    # $100,000
          },
          geographic_limits: {
            us: Money.new(1000000),          # $10,000
            eu: Money.new(500000),           # $5,000
            other: Money.new(100000)         # $1,000
          },
          age_limits: {
            new_account_days: 30,
            new_account_limit: Money.new(10000),    # $100
            established_limit: Money.new(1000000)   # $10,000
          }
        }
      }
    end
  end

  def calculate_current_velocity
    # Calculate current transaction velocity
    now = Time.current

    {
      daily: calculate_velocity_for_period(now.beginning_of_day, now.end_of_day),
      monthly: calculate_velocity_for_period(now.beginning_of_month, now.end_of_month),
      hourly: calculate_velocity_for_period(now.beginning_of_hour, now.end_of_hour)
    }
  end

  def calculate_velocity_for_period(start_time, end_time)
    transactions = @payment_account.payment_transactions
                                   .where(created_at: start_time..end_time)
                                   .where(status: :completed)

    transactions.sum(:amount_cents)
  end

  def calculate_age_based_limit(age_limits)
    account_age_days = ((Time.current - @payment_account.created_at) / 1.day).to_i

    if account_age_days < age_limits[:new_account_days]
      age_limits[:new_account_limit]
    else
      age_limits[:established_limit]
    end
  end

  def validate_amount_limits(transaction_data)
    amount = transaction_data[:amount]

    # Check minimum amount
    min_amount = @rules_config[:amount_limits][:minimum] || Money.new(100) # $1
    return failure_result("Amount below minimum: #{amount} < #{min_amount}") if amount < min_amount

    # Check maximum amount
    max_amount = @rules_config[:amount_limits][:maximum] || Money.new(1000000) # $10,000
    return failure_result("Amount above maximum: #{amount} > #{max_amount}") if amount > max_amount

    success_result('Amount limits validation passed')
  end

  def validate_velocity_rules(transaction_data)
    amount = transaction_data[:amount]
    current_velocity = calculate_current_velocity

    # Check if transaction would exceed velocity limits
    projected_daily = current_velocity[:daily] + amount.cents
    projected_hourly = current_velocity[:hourly] + amount.cents

    daily_limit = @rules_config[:velocity_limits][:daily_limit].cents
    hourly_limit = @rules_config[:velocity_limits][:hourly_limit].cents

    if projected_daily > daily_limit
      return failure_result("Transaction would exceed daily limit: #{projected_daily} > #{daily_limit}")
    end

    if projected_hourly > hourly_limit
      return failure_result("Transaction would exceed hourly limit: #{projected_hourly} > #{hourly_limit}")
    end

    success_result('Velocity rules validation passed')
  end

  def validate_risk_rules(transaction_data)
    risk_level = @payment_account.risk_level
    amount = transaction_data[:amount]

    # High-risk accounts have stricter limits
    risk_amount_limits = {
      low: Money.new(1000000),     # $10,000
      medium: Money.new(100000),   # $1,000
      high: Money.new(10000),      # $100
      critical: Money.new(1000),   # $10
      extreme: Money.new(0)        # $0
    }

    limit = risk_amount_limits[risk_level.to_sym] || Money.new(0)
    return failure_result("Risk level #{risk_level} exceeds amount limit: #{amount} > #{limit}") if amount > limit

    success_result('Risk rules validation passed')
  end

  def validate_regulatory_rules(transaction_data)
    # Validate against regulatory requirements
    amount = transaction_data[:amount]

    # Check for structuring (many small transactions to avoid reporting)
    recent_small_transactions = @payment_account.payment_transactions
                                               .where(created_at: 24.hours.ago..Time.current)
                                               .where('amount_cents < ?', 10000) # $100
                                               .count

    if recent_small_transactions > 10
      return failure_result('Potential structuring detected: too many small transactions')
    end

    # Check for required reporting thresholds
    if amount >= Money.new(1000000) # $10,000
      # Would trigger CTR (Currency Transaction Report) requirement
      # Implementation would handle regulatory reporting
    end

    success_result('Regulatory rules validation passed')
  end

  def validate_business_hours(transaction_data)
    # Validate transaction timing
    current_hour = Time.current.hour

    # Business hours validation (simplified)
    unless (9..17).include?(current_hour)
      return failure_result('Transaction outside business hours')
    end

    success_result('Business hours validation passed')
  end

  def default_risk_multipliers
    {
      low: 1.0,
      medium: 0.8,
      high: 0.5,
      critical: 0.2,
      extreme: 0.0
    }
  end
end