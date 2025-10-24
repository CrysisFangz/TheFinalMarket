# MultiCurrencyWalletCurrencyExchangeService
# Handles currency exchange operations for multi-currency wallets
class MultiCurrencyWalletCurrencyExchangeService
  def initialize(wallet)
    @wallet = wallet
  end

  def execute_exchange!(from_currency_code, to_currency_code, amount_cents, exchange_context = {})
    return false unless @wallet.active?

    exchange_service = GlobalCurrencyExchangeService.new

    exchange_request = {
      wallet_id: @wallet.id,
      user_id: @wallet.user_id,
      from_currency: from_currency_code,
      to_currency: to_currency_code,
      amount_cents: amount_cents,
      exchange_context: exchange_context.merge({
        fee_application: :monetized,
        base_fee_cents: 100, # $1.00 fee
        liquidity_optimization: true,
        compliance_validation: true
      })
    }

    exchange_service.execute_currency_exchange(exchange_request, user_context)
  end

  private

  def user_context
    {
      user_id: @wallet.user_id,
      wallet_id: @wallet.id,
      wallet_type: @wallet.wallet_type,
      global_commerce_enabled: @wallet.global_commerce_enabled?,
      liquidity_provider_status: @wallet.liquidity_provider_status,
      risk_level: @wallet.risk_level,
      fee_structure: @wallet.fee_structure
    }
  end
end