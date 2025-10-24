class MultiCurrencyWalletBalanceUpdateService
  attr_reader :balance

  def initialize(balance)
    @balance = balance
  end

  def update_balance!(new_balance_cents, exchange_rate = nil)
    Rails.logger.info("Updating balance for MultiCurrencyWalletBalance ID: #{balance.id}")
    MultiCurrencyWalletBalance.transaction do
      # Update balance atomically
      balance.update!(
        balance_cents: new_balance_cents,
        last_updated_at: Time.current,
        exchange_rate_at_balance: exchange_rate || balance.current_exchange_rate,
        previous_balance_cents: balance.balance_cents,
        balance_updated_by: extract_update_context
      )

      # Update wallet total balance
      balance.multi_currency_wallet.update_total_balance!

      # Trigger real-time balance synchronization
      trigger_balance_synchronization

      # Record balance change activity
      record_balance_change_activity(new_balance_cents)

      Rails.logger.info("Balance updated successfully for MultiCurrencyWalletBalance ID: #{balance.id}")
      true
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error updating balance for MultiCurrencyWalletBalance ID: #{balance.id} - #{e.message}")
    false
  rescue StandardError => e
    Rails.logger.error("Error updating balance for MultiCurrencyWalletBalance ID: #{balance.id} - #{e.message}")
    false
  end

  private

  def trigger_balance_synchronization
    # Trigger real-time balance updates across all connected services
    BalanceSynchronizationService.synchronize_wallet_balance(
      multi_currency_wallet_id: balance.multi_currency_wallet_id,
      currency_code: balance.currency.code,
      new_balance_cents: balance.balance_cents,
      update_context: extract_update_context
    )
  end

  def record_balance_change_activity(new_balance_cents)
    change_cents = new_balance_cents - (balance.previous_balance_cents || 0)

    balance.multi_currency_wallet.record_wallet_activity!(:balance_updated, {
      currency_code: balance.currency.code,
      previous_balance_cents: balance.previous_balance_cents,
      new_balance_cents: new_balance_cents,
      change_cents: change_cents,
      usd_equivalent_cents: balance.usd_equivalent_cents,
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
    case balance.previous_balance_cents
    when nil then :initial_balance
    when balance.balance_cents then :rate_adjustment_only
    else :actual_balance_change
    end
  end
end