class LoyaltyTokenStakingService
  attr_reader :loyalty_token

  def initialize(loyalty_token)
    @loyalty_token = loyalty_token
  end

  def stake(amount, duration_days)
    Rails.logger.info("Staking #{amount} tokens for #{duration_days} days for LoyaltyToken ID: #{loyalty_token.id}")
    return false if loyalty_token.balance < amount

    # Calculate rewards (APY based on duration)
    apy = calculate_staking_apy(duration_days)
    reward_amount = (amount * apy / 365.0 * duration_days).to_i

    loyalty_token.transaction do
      loyalty_token.decrement!(:balance, amount)
      loyalty_token.increment!(:staked_balance, amount)

      loyalty_token.token_rewards.create!(
        reward_type: :staking,
        amount_staked: amount,
        reward_amount: reward_amount,
        apy: apy,
        starts_at: Time.current,
        ends_at: duration_days.days.from_now,
        status: :active
      )
    end
    Rails.logger.info("Tokens staked successfully for LoyaltyToken ID: #{loyalty_token.id}")
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error staking tokens for LoyaltyToken ID: #{loyalty_token.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error staking tokens for LoyaltyToken ID: #{loyalty_token.id} - #{e.message}")
    raise
  end

  def unstake(reward_id)
    Rails.logger.info("Unstaking reward ID: #{reward_id} for LoyaltyToken ID: #{loyalty_token.id}")
    reward = loyalty_token.token_rewards.find(reward_id)
    return false unless reward.active?

    loyalty_token.transaction do
      # Return staked amount
      loyalty_token.increment!(:balance, reward.amount_staked)
      loyalty_token.decrement!(:staked_balance, reward.amount_staked)

      # Pay rewards if matured
      if reward.ends_at <= Time.current
        loyalty_token.increment!(:balance, reward.reward_amount)
        reward.update!(status: :completed, claimed_at: Time.current)
      else
        # Early withdrawal penalty
        penalty = (reward.reward_amount * 0.5).to_i
        loyalty_token.increment!(:balance, penalty)
        reward.update!(status: :early_withdrawal, claimed_at: Time.current)
      end
    end
    Rails.logger.info("Tokens unstaked successfully for LoyaltyToken ID: #{loyalty_token.id}")
    true
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Reward not found for unstaking in LoyaltyToken ID: #{loyalty_token.id} - #{e.message}")
    false
  rescue StandardError => e
    Rails.logger.error("Error unstaking tokens for LoyaltyToken ID: #{loyalty_token.id} - #{e.message}")
    raise
  end

  private

  def calculate_staking_apy(duration_days)
    # Higher APY for longer staking periods
    case duration_days
    when 0..30
      5.0 # 5% APY
    when 31..90
      10.0 # 10% APY
    when 91..180
      15.0 # 15% APY
    when 181..365
      20.0 # 20% APY
    else
      25.0 # 25% APY for 1+ year
    end
  end
end