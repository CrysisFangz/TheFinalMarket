class WalletPassPresenter
  def initialize(wallet_pass)
    @wallet_pass = wallet_pass
  end

  def details
    {
      pass_type: @wallet_pass.pass_type,
      pass_name: @wallet_pass.pass_name,
      barcode_value: @wallet_pass.barcode_value,
      barcode_format: @wallet_pass.barcode_format,
      expiry_date: @wallet_pass.expiry_date,
      status: @wallet_pass.status,
      data: @wallet_pass.pass_data
    }
  end
end