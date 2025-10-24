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

  # Delegated to MultiCurrencyWalletBalanceUpdateService
  def update_balance!(new_balance_cents, exchange_rate = nil)
    @update_service ||= MultiCurrencyWalletBalanceUpdateService.new(self)
    @update_service.update_balance!(new_balance_cents, exchange_rate)
  end

  # Delegated to MultiCurrencyWalletBalanceCalculationService
  def balance
    @calculation_service ||= MultiCurrencyWalletBalanceCalculationService.new(self)
    @calculation_service.balance
  end

  def balance_formatted
    @calculation_service ||= MultiCurrencyWalletBalanceCalculationService.new(self)
    @calculation_service.balance_formatted
  end

  def usd_equivalent_cents
    @calculation_service ||= MultiCurrencyWalletBalanceCalculationService.new(self)
    @calculation_service.usd_equivalent_cents
  end

  def usd_equivalent
    @calculation_service ||= MultiCurrencyWalletBalanceCalculationService.new(self)
    @calculation_service.usd_equivalent
  end

  def usd_equivalent_formatted
    @calculation_service ||= MultiCurrencyWalletBalanceCalculationService.new(self)
    @calculation_service.usd_equivalent_formatted
  end

  def sufficient_for?(required_cents)
    @calculation_service ||= MultiCurrencyWalletBalanceCalculationService.new(self)
    @calculation_service.sufficient_for?(required_cents)
  end

  def current_exchange_rate
    @calculation_service ||= MultiCurrencyWalletBalanceCalculationService.new(self)
    @calculation_service.current_exchange_rate
  end

  # Delegated to MultiCurrencyWalletBalanceCalculationService
  def balance_value_change_cents
    @calculation_service ||= MultiCurrencyWalletBalanceCalculationService.new(self)
    @calculation_service.balance_value_change_cents
  end

  def balance_value_change_percentage
    @calculation_service ||= MultiCurrencyWalletBalanceCalculationService.new(self)
    @calculation_service.balance_value_change_percentage
  end

  def balance_health_score
    @calculation_service ||= MultiCurrencyWalletBalanceCalculationService.new(self)
    @calculation_service.balance_health_score
  end

  def requires_attention?
    @calculation_service ||= MultiCurrencyWalletBalanceCalculationService.new(self)
    @calculation_service.requires_attention?
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