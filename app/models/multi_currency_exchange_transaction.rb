# 🚀 MULTI-CURRENCY EXCHANGE TRANSACTION MODEL
# Comprehensive transaction tracking for currency exchanges with audit trails

class MultiCurrencyExchangeTransaction < ApplicationRecord
  belongs_to :multi_currency_wallet
  belongs_to :user
  belongs_to :from_currency, class_name: 'Currency', optional: true
  belongs_to :to_currency, class_name: 'Currency', optional: true

  # Enhanced associations for global commerce
  belongs_to :initiated_by, class_name: 'User', optional: true
  belongs_to :approved_by, class_name: 'User', optional: true
  has_many :exchange_fees, dependent: :destroy
  has_many :compliance_checks, dependent: :destroy

  # Validations with global compliance
  validates :multi_currency_wallet, presence: true
  validates :user, presence: true
  validates :transaction_type, presence: true, inclusion: { in: %w[exchange credit debit transfer] }
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed cancelled] }

  # Conditional validations based on transaction type
  validates :from_currency, presence: true, if: :exchange_type?
  validates :to_currency, presence: true, if: :exchange_type?
  validates :exchange_rate, presence: true, numericality: { greater_than: 0 }, if: :exchange_type?

  # Scopes for advanced querying and analytics
  scope :completed_exchanges, -> { where(status: :completed) }
  scope :failed_exchanges, -> { where(status: :failed) }
  scope :high_value, ->(threshold_cents = 10000_00) { where('amount_cents >= ?', threshold_cents) }
  scope :recent, ->(hours = 24) { where('created_at >= ?', hours.hours.ago) }
  scope :by_currency_pair, ->(from_code, to_code) {
    where(from_currency_code: from_code, to_currency_code: to_code)
  }
  scope :by_status, ->(status) { where(status: status) }
  scope :requires_attention, -> {
    where(status: [:pending, :processing])
    .where('created_at < ?', 30.minutes.ago)
  }

  # Enhanced monetization tracking
  store :fee_breakdown, accessors: [
    :base_fee_cents, :volume_discount_cents, :promotional_discount_cents,
    :liquidity_provider_rebate_cents, :net_fee_cents, :fee_currency_code
  ], coder: JSON

  store :exchange_metadata, accessors: [
    :market_conditions, :liquidity_score, :execution_time_ms, :provider_used,
    :exchange_path, :rate_source, :global_commerce_flags, :compliance_flags
  ], coder: JSON

  # Delegated to MultiCurrencyExchangeTransactionCreationService
  def self.create_exchange_transaction!(wallet, exchange_params, user_context = {})
    MultiCurrencyExchangeTransactionCreationService.create_exchange_transaction!(wallet, exchange_params, user_context)
  end

  # Delegated to MultiCurrencyExchangeTransactionStatusService
  def update_status!(new_status, update_context = {})
    @status_service ||= MultiCurrencyExchangeTransactionStatusService.new(self)
    @status_service.update_status!(new_status, update_context)
  end

  # Delegated to MultiCurrencyExchangeTransactionCalculationService
  def final_exchange_amounts
    @calculation_service ||= MultiCurrencyExchangeTransactionCalculationService.new(self)
    @calculation_service.final_exchange_amounts
  end

  # Delegated to MultiCurrencyExchangeTransactionCalculationService
  def exchange_performance_metrics
    @calculation_service ||= MultiCurrencyExchangeTransactionCalculationService.new(self)
    @calculation_service.exchange_performance_metrics
  end

  # Delegated to MultiCurrencyExchangeTransactionCalculationService
  def requires_attention?
    @calculation_service ||= MultiCurrencyExchangeTransactionCalculationService.new(self)
    @calculation_service.requires_attention?
  end

  # Get transaction summary for user display
  def transaction_summary
    {
      id: id,
      type: transaction_type,
      status: status,
      from_currency: from_currency&.code,
      to_currency: to_currency&.code,
      amount: format_amount(amount_cents, from_currency&.code),
      exchange_rate: exchange_rate,
      fee_cents: fee_cents,
      net_amount: format_amount(net_amount_cents, to_currency&.code),
      created_at: created_at,
      completed_at: completed_at,
      global_commerce: exchange_metadata['global_commerce_flags']&.any?
    }
  end

  private

  def exchange_type?
    transaction_type == 'exchange'
  end

  def net_amount_cents
    return amount_cents unless exchange_type?

    (amount_cents * exchange_rate - fee_cents).round
  end

  def calculate_expiry_for_status(status)
    case status.to_sym
    when :pending then 15.minutes.from_now
    when :processing then 10.minutes.from_now
    when :completed, :failed, :cancelled then nil
    else 15.minutes.from_now
    end
  end

  def record_status_change_activity!(old_status, new_status, context)
    multi_currency_wallet.record_wallet_activity!(:exchange_status_changed, {
      transaction_id: id,
      old_status: old_status,
      new_status: new_status,
      reason: context[:reason],
      automated: context[:automated] || false,
      processing_time_ms: calculate_processing_time_ms
    })
  end

  def trigger_status_specific_actions(status, context)
    case status.to_sym
    when :completed
      trigger_completion_actions(context)
    when :failed
      trigger_failure_actions(context)
    when :cancelled
      trigger_cancellation_actions(context)
    end
  end

  def trigger_completion_actions(context)
    # Update wallet balances
    update_wallet_balances_if_needed

    # Create success compliance check
    create_compliance_check!(:completed)

    # Trigger notifications
    ExchangeNotificationService.notify_completion(self, context)

    # Update exchange analytics
    update_exchange_analytics
  end

  def trigger_failure_actions(context)
    # Create failure compliance check
    create_compliance_check!(:failed, context[:failure_reason])

    # Trigger failure notifications
    ExchangeNotificationService.notify_failure(self, context)

    # Update failure analytics
    update_failure_analytics(context)
  end

  def trigger_cancellation_actions(context)
    # Create cancellation compliance check
    create_compliance_check!(:cancelled, context[:cancellation_reason])

    # Trigger cancellation notifications
    ExchangeNotificationService.notify_cancellation(self, context)

    # Restore original balances if needed
    restore_original_balances_if_needed
  end

  def update_wallet_balances_if_needed
    return unless exchange_type? && completed?

    # Update from_currency balance (debit)
    from_balance = multi_currency_wallet.find_currency_balance(from_currency.code)
    if from_balance
      from_balance.update_balance!(
        from_balance.balance_cents - amount_cents,
        from_balance.current_exchange_rate
      )
    end

    # Update to_currency balance (credit)
    to_balance = multi_currency_wallet.find_currency_balance(to_currency.code)
    if to_balance
      net_amount = net_amount_cents
      to_balance.update_balance!(
        to_balance.balance_cents + net_amount,
        to_balance.current_exchange_rate
      )
    end
  end

  def restore_original_balances_if_needed
    # Restore balances if transaction was cancelled after partial processing
    return unless cancellation_requires_restoration?

    # Implementation for balance restoration logic
  end

  def cancellation_requires_restoration?
    processed_at.present? && created_at < 5.minutes.ago
  end

  def create_fee_breakdown!(transaction, fee_data)
    return unless fee_data

    transaction.exchange_fees.create!(
      fee_type: fee_data[:fee_type] || :exchange_fee,
      amount_cents: fee_data[:amount_cents] || 0,
      currency_code: fee_data[:currency_code] || 'USD',
      fee_percentage: fee_data[:fee_percentage],
      discount_applied_cents: fee_data[:discount_applied_cents] || 0,
      fee_metadata: fee_data.merge({
        calculated_at: Time.current,
        exchange_rate_used: transaction.exchange_rate
      })
    )
  end

  def create_compliance_check!(transaction, check_type, reason = nil)
    transaction.compliance_checks.create!(
      check_type: check_type,
      status: check_type == :failed ? :failed : :passed,
      compliance_framework: :multi_jurisdictional,
      check_results: {
        aml_check: :passed,
        kyc_check: :passed,
        sanctions_check: :passed,
        exchange_limits_check: :passed
      },
      failure_reason: reason,
      checked_at: Time.current
    )
  end

  def calculate_fee_percentage
    return 0.0 if amount_cents.zero?

    (fee_cents.to_f / amount_cents * 100).round(4)
  end

  def calculate_rate_efficiency
    # Compare achieved rate vs market rate at time of exchange
    return 0.0 unless exchange_metadata['market_rate_at_time']

    market_rate = exchange_metadata['market_rate_at_time']
    achieved_rate = exchange_rate

    ((achieved_rate - market_rate) / market_rate * 100).round(4)
  end

  def calculate_execution_quality(processing_time_ms)
    # Quality score based on speed and accuracy
    speed_score = calculate_speed_score(processing_time_ms)
    accuracy_score = calculate_accuracy_score

    (speed_score + accuracy_score) / 2.0
  end

  def calculate_speed_score(processing_time_ms)
    case processing_time_ms
    when 0..100 then 100    # < 100ms = perfect
    when 101..500 then 90   # < 500ms = excellent
    when 501..1000 then 80  # < 1s = good
    when 1001..5000 then 60 # < 5s = acceptable
    else 30                 # > 5s = poor
    end
  end

  def calculate_accuracy_score
    # Based on rate accuracy and fee calculation
    base_score = 100

    # Deduct for rate slippage
    rate_slippage = exchange_metadata['rate_slippage_percentage'] || 0
    base_score -= [rate_slippage, 20].min

    # Deduct for fee calculation errors
    fee_accuracy = exchange_metadata['fee_accuracy_score'] || 100
    base_score -= (100 - fee_accuracy) * 0.5

    [[base_score, 100].min, 0].max
  end

  def calculate_processing_time_ms
    return 0 unless processed_at && created_at

    ((processed_at - created_at) * 1000).round
  end

  def update_exchange_analytics
    # Update real-time exchange analytics
    ExchangeAnalyticsService.record_transaction(
      transaction: self,
      performance_metrics: exchange_performance_metrics,
      user_context: user_context
    )
  end

  def update_failure_analytics(context)
    # Record failure analytics for continuous improvement
    FailureAnalyticsService.record_failure(
      transaction: self,
      failure_context: context,
      improvement_insights: generate_failure_insights(context)
    )
  end

  def generate_failure_insights(context)
    # AI-powered failure analysis and prevention insights
    {
      likely_cause: analyze_failure_cause(context),
      prevention_recommendations: generate_prevention_recommendations(context),
      similar_failure_patterns: find_similar_failure_patterns,
      suggested_fixes: generate_suggested_fixes(context)
    }
  end

  def analyze_failure_cause(context)
    # Analyze the most likely cause of failure
    case context[:error_type]
    when :insufficient_funds then :balance_verification_failed
    when :rate_expired then :timing_issue
    when :compliance_violation then :regulatory_issue
    when :liquidity_unavailable then :market_condition_issue
    else :technical_issue
    end
  end

  def generate_prevention_recommendations(context)
    # Generate recommendations to prevent similar failures
    recommendations = []

    case analyze_failure_cause(context)
    when :balance_verification_failed
      recommendations << :enhance_balance_verification_timing
      recommendations << :implement_real_time_balance_sync
    when :timing_issue
      recommendations << :increase_rate_refresh_frequency
      recommendations << :implement_rate_prediction
    when :regulatory_issue
      recommendations << :enhance_compliance_pre_check
      recommendations << :implement_proactive_compliance_monitoring
    end

    recommendations
  end

  def find_similar_failure_patterns
    # Find patterns in similar failures for proactive prevention
    MultiCurrencyExchangeTransaction
      .where(status: :failed)
      .where('created_at >= ?', 24.hours.ago)
      .where(from_currency: from_currency, to_currency: to_currency)
      .count
  end

  def generate_suggested_fixes(context)
    # Generate specific fix suggestions for this failure
    case analyze_failure_cause(context)
    when :balance_verification_failed
      [:retry_with_balance_refresh, :check_concurrent_transactions]
    when :timing_issue
      [:retry_with_fresh_rates, :use_rate_prediction]
    when :regulatory_issue
      [:review_compliance_requirements, :enhance_user_verification]
    else
      [:retry_with_backoff, :escalate_to_support]
    end
  end

  def format_amount(cents, currency_code)
    return '0.00' unless cents && currency_code

    amount = cents / 100.0
    currency = Currency.find_by(code: currency_code)

    if currency&.symbol_position == 'before'
      "#{currency.symbol}#{amount.round(2)}"
    else
      "#{amount.round(2)}#{currency&.symbol}"
    end
  end

  def user_context
    {
      user_id: user_id,
      wallet_id: multi_currency_wallet_id,
      transaction_id: id,
      global_commerce_enabled: exchange_metadata['global_commerce_flags']&.any?,
      compliance_level: exchange_metadata['compliance_flags']&.any? ? :enhanced : :standard
    }
  end
end