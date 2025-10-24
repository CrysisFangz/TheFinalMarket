class MultiCurrencyWalletBalanceCalculationService
  attr_reader :balance

  def initialize(balance)
    @balance = balance
  end

  def balance
    Rails.logger.debug("Getting balance for MultiCurrencyWalletBalance ID: #{balance.id}")
    balance.balance_cents / 100.0
  end

  def balance_formatted
    Rails.logger.debug("Getting formatted balance for MultiCurrencyWalletBalance ID: #{balance.id}")
    balance.currency.format_amount(balance.balance_cents)
  end

  def usd_equivalent_cents
    Rails.logger.debug("Getting USD equivalent cents for MultiCurrencyWalletBalance ID: #{balance.id}")
    (balance.balance_cents * balance.exchange_rate_at_balance).round
  end

  def usd_equivalent
    Rails.logger.debug("Getting USD equivalent for MultiCurrencyWalletBalance ID: #{balance.id}")
    usd_equivalent_cents / 100.0
  end

  def usd_equivalent_formatted
    Rails.logger.debug("Getting formatted USD equivalent for MultiCurrencyWalletBalance ID: #{balance.id}")
    "$#{usd_equivalent.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end

  def sufficient_for?(required_cents)
    Rails.logger.debug("Checking if balance is sufficient for #{required_cents} cents in MultiCurrencyWalletBalance ID: #{balance.id}")
    balance.balance_cents >= required_cents
  end

  def current_exchange_rate
    Rails.logger.debug("Getting current exchange rate for MultiCurrencyWalletBalance ID: #{balance.id}")
    Rails.cache.fetch("exchange_rate:#{balance.currency.code}", expires_in: 1.hour) do
      balance.currency.current_exchange_rate
    end
  end

  def balance_value_change_cents
    Rails.logger.debug("Calculating balance value change cents for MultiCurrencyWalletBalance ID: #{balance.id}")
    return 0 if balance.previous_balance_cents.blank?

    current_usd_value = usd_equivalent_cents
    previous_usd_value = (balance.previous_balance_cents * balance.exchange_rate_at_balance).round

    current_usd_value - previous_usd_value
  end

  def balance_value_change_percentage
    Rails.logger.debug("Calculating balance value change percentage for MultiCurrencyWalletBalance ID: #{balance.id}")
    return 0.0 if balance.previous_balance_cents.blank? || balance.previous_balance_cents.zero?

    change_cents = balance_value_change_cents
    (change_cents.to_f / (balance.previous_balance_cents * balance.exchange_rate_at_balance) * 100).round(2)
  end

  def balance_health_score
    Rails.logger.debug("Calculating balance health score for MultiCurrencyWalletBalance ID: #{balance.id}")
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

  def requires_attention?
    Rails.logger.debug("Checking if balance requires attention for MultiCurrencyWalletBalance ID: #{balance.id}")
    balance_health_score < 70 || stale_balance? || unusual_activity?
  end

  private

  def stale_balance?
    balance.last_updated_at < 24.hours.ago
  end

  def unusual_activity?
    # Detect unusual balance changes based on historical patterns
    return false unless balance.previous_balance_cents.present?

    change_percentage = (balance_value_change_cents.to_f / usd_equivalent_cents.abs * 100).abs
    change_percentage > 50 # Flag if more than 50% change in value
  end

  def stale_balance_penalty
    return 0 if balance.last_updated_at > 1.hour.ago
    return 10 if balance.last_updated_at > 6.hours.ago
    return 25 if balance.last_updated_at > 24.hours.ago
    50 # Very stale
  end

  def unusual_activity_penalty
    unusual_activity? ? 20 : 0
  end

  def active_balance_bonus
    balance.balance_cents > 0 ? 5 : 0
  end

  def diversification_bonus
    # Bonus for using non-USD currencies in global commerce
    balance.currency.code != 'USD' ? 5 : 0
  end
end