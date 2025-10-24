class MobileWalletPassService
  attr_reader :mobile_wallet

  def initialize(mobile_wallet)
    @mobile_wallet = mobile_wallet
  end

  def add_pass(pass_params)
    Rails.logger.info("Adding pass to MobileWallet ID: #{mobile_wallet.id}")
    pass = mobile_wallet.wallet_passes.create!(
      pass_type: pass_params[:pass_type],
      pass_name: pass_params[:pass_name],
      pass_identifier: pass_params[:pass_identifier],
      barcode_value: pass_params[:barcode_value],
      barcode_format: pass_params[:barcode_format],
      expiry_date: pass_params[:expiry_date],
      pass_data: pass_params[:pass_data] || {},
      added_at: Time.current
    )
    Rails.logger.info("Pass added successfully to MobileWallet ID: #{mobile_wallet.id}")
    pass
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error adding pass to MobileWallet ID: #{mobile_wallet.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error adding pass to MobileWallet ID: #{mobile_wallet.id} - #{e.message}")
    raise
  end
end