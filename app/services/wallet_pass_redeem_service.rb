class WalletPassRedeemService
  attr_reader :wallet_pass, :errors

  def initialize(wallet_pass)
    @wallet_pass = wallet_pass
    @errors = []
  end

  def call
    return false unless valid_for_redemption?

    ActiveRecord::Base.transaction do
      wallet_pass.update!(
        status: :redeemed,
        redeemed_at: Time.current
      )
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    @errors << e.message
    false
  end

  private

  def valid_for_redemption?
    if wallet_pass.redeemed?
      @errors << "Pass has already been redeemed"
      return false
    end

    if wallet_pass.expired?
      @errors << "Pass has expired"
      return false
    end

    true
  end
end