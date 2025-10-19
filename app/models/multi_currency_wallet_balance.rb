# 🚀 MULTI-CURRENCY WALLET BALANCE MODEL
# Advanced balance tracking for multi-currency wallets with real-time synchronization

class MultiCurrencyWalletBalance < ApplicationRecord
  belongs_to :multi_currency_wallet
  belongs_to :currency

  validates :multi_currency_wallet, presence: true
  validates :currency, presence: true, uniqueness: { scope: :multi_currency_wallet_id }
  validates :balance_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :exchange_rate_at_balance, presence: true, numericality: { greater_than: 0 }

  # Scopes for advanced querying
  scope :positive_balances, -> { where('balance_cents > 0') }
  scope :primary_currencies, -> { where(is_primary: true) }
  scope :recently_updated, -> { where('last_updated_at > ?', 1.hour.ago) }
  scope :high_value, ->(threshold_cents = 1000_00) { where('balance_cents >= ?', threshold_cents) }
  scope :by_currency_code, ->(code) { joins(:currency).where(currencies: { code: code }) }

  # Update balance with atomic operations and real-time synchronization
  def update_balance!(new_balance_cents, exchange_rate = nil)
    MultiCurrencyWalletBalance.transaction do
      # Update balance atomically
      update!(
        balance_cents: new_balance_cents,
        last_updated_at: Time.current,
        exchange_rate_at_balance: exchange_rate || current_exchange_rate,
        previous_balance_cents: balance_cents,
        balance_updated_by: extract_update_context
      )

      # Update wallet total balance
      multi_currency_wallet.update_total_balance!

      # Trigger real-time balance synchronization
      trigger_balance_synchronization

      # Record balance change activity
      record_balance_change_activity(new_balance_cents)
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to update wallet balance: #{e.message}"
    false
  end

  # Get balance in various formats
  def balance
    balance_cents / 100.0
  end

  def balance_formatted
    currency.format_amount(balance_cents)
  end

  def usd_equivalent_cents
    (balance_cents * exchange_rate_at_balance).round
  end

  def usd_equivalent
    usd_equivalent_cents / 100.0
  end

  def usd_equivalent_formatted
    "$#{usd_equivalent.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end

  # Check if balance is sufficient for transaction
  def sufficient_for?(required_cents)
    balance_cents >= required_cents
  end

  # Get current exchange rate with caching
  def current_exchange_rate
    Rails.cache.fetch("exchange_rate:#{currency.code}", expires_in: 1.hour) do
      currency.current_exchange_rate
    end
  end

  # Calculate balance value change since last update
  def balance_value_change_cents
    return 0 if previous_balance_cents.blank?

    current_usd_value = usd_equivalent_cents
    previous_usd_value = (previous_balance_cents * exchange_rate_at_balance).round

    current_usd_value - previous_usd_value
  end

  def balance_value_change_percentage
    return 0.0 if previous_balance_cents.blank? || previous_balance_cents.zero?

    change_cents = balance_value_change_cents
    (change_cents.to_f / (previous_balance_cents * exchange_rate_at_balance) * 100).round(2)
  end

  # Get balance health indicators
  def balance_health_score
    calculate_balance_health_score
  end

  def requires_attention?
    balance_health_score < 70 || stale_balance? || unusual_activity?
  end

  private

  def trigger_balance_synchronization
    # Trigger real-time balance updates across all connected services
    BalanceSynchronizationService.synchronize_wallet_balance(
      multi_currency_wallet_id: multi_currency_wallet_id,
      currency_code: currency.code,
      new_balance_cents: balance_cents,
      update_context: extract_update_context
    )
  end

  def record_balance_change_activity(new_balance_cents)
    change_cents = new_balance_cents - (previous_balance_cents || 0)

    multi_currency_wallet.record_wallet_activity!(:balance_updated, {
      currency_code: currency.code,
      previous_balance_cents: previous_balance_cents,
      new_balance_cents: new_balance_cents,
      change_cents: change_cents,
      usd_equivalent_cents: usd_equivalent_cents,
      update_reason: extract_update_reason
    })
  end

  def extract_update_context
    {
      timestamp: Time.current,
      source: 'balance_update',
      ip_address: Current.request_ip,
      user_agent: Current.user_agent,
      session_id: Current.session_id
    }
  end

  def extract_update_reason
    # Analyze the context to determine why balance was updated
    case previous_balance_cents
    when nil then :initial_balance
    when balance_cents then :rate_adjustment_only
    else :actual_balance_change
    end
  end

  def stale_balance?
    last_updated_at < 24.hours.ago
  end

  def unusual_activity?
    # Detect unusual balance changes based on historical patterns
    return false unless previous_balance_cents.present?

    change_percentage = (balance_value_change_cents.to_f / usd_equivalent_cents.abs * 100).abs
    change_percentage > 50 # Flag if more than 50% change in value
  end

  def calculate_balance_health_score
    score = 100

    # Deduct points for stale data
    score -= stale_balance_penalty

    # Deduct points for unusual activity
    score -= unusual_activity_penalty

    # Bonus points for active balances
    score += active_balance_bonus

    # Bonus points for well-diversified currency
    score += diversification_bonus

    [[score, 100].min, 0].max
  end

  def stale_balance_penalty
    return 0 if last_updated_at > 1.hour.ago
    return 10 if last_updated_at > 6.hours.ago
    return 25 if last_updated_at > 24.hours.ago
    50 # Very stale
  end

  def unusual_activity_penalty
    unusual_activity? ? 20 : 0
  end

  def active_balance_bonus
    balance_cents > 0 ? 5 : 0
  end

  def diversification_bonus
    # Bonus for using non-USD currencies in global commerce
    currency.code != 'USD' ? 5 : 0
  end
end