class MultiCurrencyExchangeTransactionCreationService
  def self.create_exchange_transaction!(wallet, exchange_params, user_context = {})
    Rails.logger.info("Creating exchange transaction for wallet ID: #{wallet.id}")
    MultiCurrencyExchangeTransaction.transaction do
      transaction = MultiCurrencyExchangeTransaction.create!(
        multi_currency_wallet: wallet,
        user: wallet.user,
        initiated_by: user_context[:initiated_by] || wallet.user,
        transaction_type: :exchange,
        from_currency: exchange_params[:from_currency],
        to_currency: exchange_params[:to_currency],
        amount_cents: exchange_params[:amount_cents],
        exchange_rate: exchange_params[:exchange_rate],
        fee_cents: exchange_params[:fee_cents] || 0,
        status: :pending,
        exchange_metadata: {
          exchange_request_id: exchange_params[:request_id],
          user_context: user_context,
          global_commerce_enabled: wallet.global_commerce_enabled?,
          compliance_level: :enhanced
        }.merge(exchange_params[:metadata] || {}),
        created_at: Time.current,
        expires_at: 15.minutes.from_now
      )

      # Create fee breakdown record
      create_fee_breakdown!(transaction, exchange_params[:fee_breakdown])

      # Create initial compliance check
      create_compliance_check!(transaction, :initiated)

      Rails.logger.info("Exchange transaction created for wallet ID: #{wallet.id}")
      transaction
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error creating exchange transaction for wallet ID: #{wallet.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error creating exchange transaction for wallet ID: #{wallet.id} - #{e.message}")
    raise
  end

  private

  def self.create_fee_breakdown!(transaction, fee_data)
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

  def self.create_compliance_check!(transaction, check_type, reason = nil)
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
end