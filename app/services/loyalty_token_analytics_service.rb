class LoyaltyTokenAnalyticsService
  attr_reader :loyalty_token

  def initialize(loyalty_token)
    @loyalty_token = loyalty_token
  end

  def pending_rewards
    Rails.logger.debug("Calculating pending rewards for LoyaltyToken ID: #{loyalty_token.id}")
    loyalty_token.token_rewards.active.sum(:reward_amount)
  end

  def transaction_history(limit = 50)
    Rails.logger.debug("Fetching transaction history for LoyaltyToken ID: #{loyalty_token.id}, limit: #{limit}")
    loyalty_token.token_transactions.order(created_at: :desc).limit(limit)
  end
end