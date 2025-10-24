class RewardDistributionService
  def self.award_to(reward, user)
    with_retry do
      case reward.prize_type
      when 'coins'
        user.increment!(:coins, reward.prize_value)
      when 'experience'
        user.increment!(:experience_points, reward.prize_value)
      when 'tokens'
        user.loyalty_token&.earn(reward.prize_value, 'seasonal_event')
      when 'badge'
        BadgeService.award_badge(reward, user)
      when 'product'
        ProductService.award_product(reward, user)
      end

      # Record the award
      record_award(reward, user)

      # Notify user
      notify_user(reward, user)
    end
  end

  private

  def self.record_award(reward, user)
    # Track that user received this reward
    user.claimed_event_rewards.create!(event_reward: reward, claimed_at: Time.current)
  end

  def self.notify_user(reward, user)
    RewardNotificationService.notify(
      user: user,
      title: "Event Reward: #{reward.reward_name}!",
      message: "You've earned a reward from #{reward.seasonal_event.name}!",
      resource: reward,
      data: { prize_type: reward.prize_type, prize_value: reward.prize_value }
    )
  end
end