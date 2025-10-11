class EventReward < ApplicationRecord
  belongs_to :seasonal_event
  
  validates :seasonal_event, presence: true
  validates :reward_type, presence: true
  validates :reward_name, presence: true
  
  enum reward_type: {
    milestone: 0,
    leaderboard: 1,
    participation: 2,
    random_drop: 3
  }
  
  # Award reward to user
  def award_to(user)
    case prize_type
    when 'coins'
      user.increment!(:coins, prize_value)
    when 'experience'
      user.increment!(:experience_points, prize_value)
    when 'tokens'
      user.loyalty_token&.earn(prize_value, 'seasonal_event')
    when 'badge'
      award_badge(user)
    when 'product'
      award_product(user)
    end
    
    # Record the award
    record_award(user)
    
    # Notify user
    notify_user(user)
  end
  
  private
  
  def award_badge(user)
    # Implementation depends on your badge system
  end
  
  def award_product(user)
    # Implementation depends on your product/voucher system
  end
  
  def record_award(user)
    # Track that user received this reward
    user.claimed_event_rewards.create!(event_reward: self, claimed_at: Time.current)
  end
  
  def notify_user(user)
    Notification.create!(
      recipient: user,
      notifiable: self,
      notification_type: 'event_reward',
      title: "Event Reward: #{reward_name}!",
      message: "You've earned a reward from #{seasonal_event.name}!",
      data: { prize_type: prize_type, prize_value: prize_value }
    )
  end
end

