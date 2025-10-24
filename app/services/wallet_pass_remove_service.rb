class WalletPassRemoveService
  attr_reader :wallet_pass, :errors

  def initialize(wallet_pass)
    @wallet_pass = wallet_pass
    @errors = []
  end

  def call
    ActiveRecord::Base.transaction do
      wallet_pass.update!(status: :removed, removed_at: Time.current)
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    @errors << e.message
    false
  end
end