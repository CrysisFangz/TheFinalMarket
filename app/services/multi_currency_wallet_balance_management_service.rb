# MultiCurrencyWalletBalanceManagementService
# Handles balance operations like add and deduct funds
class MultiCurrencyWalletBalanceManagementService
  def initialize(wallet)
    @wallet = wallet
  end

  def add_funds!(currency_code, amount_cents, source, metadata = {})
    return false unless @wallet.active?

    currency = find_or_create_currency_balance(currency_code)
    return false unless currency

    with_currency_lock(currency_code) do
      MultiCurrencyWalletBalance.transaction do
        transaction = @wallet.exchange_transactions.create!(
          transaction_type: :credit,
          from_currency: currency_code,
          to_currency: nil,
          amount_cents: amount_cents,
          fee_cents: 0,
          exchange_rate: currency.current_exchange_rate,
          source: source,
          status: :completed,
          transaction_data: metadata.merge({
            global_commerce_enabled: @wallet.global_commerce_enabled?,
            liquidity_optimization: true
          }),
          processed_at: Time.current,
          completed_at: Time.current
        )

        currency.update!(
          balance_cents: currency.balance_cents + amount_cents,
          last_updated_at: Time.current,
          exchange_rate_at_balance: currency.current_exchange_rate
        )

        @wallet.update_total_balance!
        @wallet.record_wallet_activity!(:funds_added, {
          currency_code: currency_code,
          amount_cents: amount_cents,
          source: source,
          transaction_id: transaction.id
        })

        transaction
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error adding funds: #{e.message}")
    false
  rescue StandardError => e
    Rails.logger.error("Error adding funds: #{e.message}")
    false
  end

  def deduct_funds!(currency_code, amount_cents, purpose, metadata = {})
    return false unless @wallet.active?
    return false if insufficient_funds?(currency_code, amount_cents)

    currency = find_currency_balance(currency_code)
    return false unless currency

    with_currency_lock(currency_code) do
      MultiCurrencyWalletBalance.transaction do
        transaction = @wallet.exchange_transactions.create!(
          transaction_type: :debit,
          from_currency: currency_code,
          to_currency: nil,
          amount_cents: amount_cents,
          fee_cents: 0,
          exchange_rate: currency.current_exchange_rate,
          purpose: purpose,
          status: :completed,
          transaction_data: metadata.merge({
            global_commerce_enabled: @wallet.global_commerce_enabled?,
            purpose_verified: true
          }),
          processed_at: Time.current,
          completed_at: Time.current
        )

        currency.update!(
          balance_cents: currency.balance_cents - amount_cents,
          last_updated_at: Time.current,
          exchange_rate_at_balance: currency.current_exchange_rate
        )

        @wallet.update_total_balance!
        @wallet.record_wallet_activity!(:funds_deducted, {
          currency_code: currency_code,
          amount_cents: amount_cents,
          purpose: purpose,
          transaction_id: transaction.id
        })

        transaction
      end
    end
  end

  private

  def find_or_create_currency_balance(currency_code)
    currency = Currency.find_by(code: currency_code)
    return nil unless currency

    @wallet.currency_balances.find_or_create_by!(currency: currency) do |balance|
      balance.balance_cents = 0
      balance.is_primary = @wallet.primary_currency_code == currency_code
      balance.last_updated_at = Time.current
      balance.exchange_rate_at_balance = currency.current_exchange_rate
    end
  end

  def find_currency_balance(currency_code)
    currency = Currency.find_by(code: currency_code)
    return nil unless currency

    @wallet.currency_balances.find_by(currency: currency)
  end

  def insufficient_funds?(currency_code, required_cents)
    balance_cents_for_currency(currency_code) < required_cents
  end

  def balance_cents_for_currency(currency_code)
    currency_balance = find_currency_balance(currency_code)
    currency_balance ? currency_balance.balance_cents : 0
  end

  def with_currency_lock(currency_code, &block)
    lock_key = "multi_currency_wallet_#{@wallet.id}_currency_#{currency_code}"
    DistributedLockManager.with_lock(lock_key, ttl: 30.seconds, &block)
  end
end