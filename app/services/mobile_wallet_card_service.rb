class MobileWalletCardService
  attr_reader :mobile_wallet

  def initialize(mobile_wallet)
    @mobile_wallet = mobile_wallet
  end

  def add_card(card_params)
    Rails.logger.info("Adding card to MobileWallet ID: #{mobile_wallet.id}")
    card = mobile_wallet.wallet_cards.create!(
      card_type: card_params[:card_type],
      last_four: card_params[:last_four],
      card_brand: card_params[:card_brand],
      expiry_month: card_params[:expiry_month],
      expiry_year: card_params[:expiry_year],
      cardholder_name: card_params[:cardholder_name],
      is_default: mobile_wallet.wallet_cards.empty?,
      token: card_params[:token],
      card_data: card_params[:metadata] || {}
    )
    Rails.logger.info("Card added successfully to MobileWallet ID: #{mobile_wallet.id}")
    card
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error adding card to MobileWallet ID: #{mobile_wallet.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error adding card to MobileWallet ID: #{mobile_wallet.id} - #{e.message}")
    raise
  end

  def default_card
    Rails.logger.debug("Getting default card for MobileWallet ID: #{mobile_wallet.id}")
    mobile_wallet.wallet_cards.active.find_by(is_default: true) || mobile_wallet.wallet_cards.active.first
  end
end