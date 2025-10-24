class LoyaltyTokenExportService
  attr_reader :loyalty_token

  def initialize(loyalty_token)
    @loyalty_token = loyalty_token
  end

  def export_to_wallet(wallet_address)
    Rails.logger.info("Exporting tokens to wallet #{wallet_address} for LoyaltyToken ID: #{loyalty_token.id}")
    # This would transfer tokens to external Web3 wallet
    # For now, just record the export

    loyalty_token.token_transactions.create!(
      transaction_type: :exported,
      amount: loyalty_token.balance,
      balance_after: 0,
      reason: 'Exported to Web3 wallet',
      metadata: { wallet_address: wallet_address }
    )

    loyalty_token.update!(balance: 0, exported_to_wallet: wallet_address)
    Rails.logger.info("Tokens exported successfully for LoyaltyToken ID: #{loyalty_token.id}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error exporting tokens for LoyaltyToken ID: #{loyalty_token.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error exporting tokens for LoyaltyToken ID: #{loyalty_token.id} - #{e.message}")
    raise
  end
end