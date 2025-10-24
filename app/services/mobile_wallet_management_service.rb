class MobileWalletManagementService
  def self.create_for_user(user)
    Rails.logger.info("Creating wallet for user ID: #{user.id}")
    wallet = MobileWallet.create!(
      user: user,
      wallet_id: generate_wallet_id,
      balance_cents: 0,
      status: :active,
      activated_at: Time.current
    )
    Rails.logger.info("Wallet created successfully for user ID: #{user.id}")
    wallet
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error creating wallet for user ID: #{user.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error creating wallet for user ID: #{user.id} - #{e.message}")
    raise
  end

  def self.suspend!(wallet, reason = nil)
    Rails.logger.info("Suspending MobileWallet ID: #{wallet.id}")
    wallet.update!(
      status: :suspended,
      suspended_at: Time.current,
      suspension_reason: reason
    )
    Rails.logger.info("MobileWallet ID: #{wallet.id} suspended successfully")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error suspending MobileWallet ID: #{wallet.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error suspending MobileWallet ID: #{wallet.id} - #{e.message}")
    raise
  end

  def self.reactivate!(wallet)
    Rails.logger.info("Reactivating MobileWallet ID: #{wallet.id}")
    wallet.update!(
      status: :active,
      suspended_at: nil,
      suspension_reason: nil
    )
    Rails.logger.info("MobileWallet ID: #{wallet.id} reactivated successfully")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error reactivating MobileWallet ID: #{wallet.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error reactivating MobileWallet ID: #{wallet.id} - #{e.message}")
    raise
  end

  private

  def self.generate_wallet_id
    loop do
      wallet_id = "MW#{SecureRandom.hex(8).upcase}"
      break wallet_id unless MobileWallet.exists?(wallet_id: wallet_id)
    end
  end
end