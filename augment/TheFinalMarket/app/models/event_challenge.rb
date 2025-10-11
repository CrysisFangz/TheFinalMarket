class EventChallenge < ApplicationRecord
  belongs_to :seasonal_event
  has_many :challenge_completions, dependent: :destroy
  
  validates :seasonal_event, presence: true
  validates :name, presence: true
  validates :challenge_type, presence: true
  validates :points_reward, numericality: { greater_than: 0 }
  
  enum challenge_type: {
    purchase: 0,
    social: 1,
    engagement: 2,
    collection: 3,
    time_limited: 4
  }
  
  # Check if user completed this challenge
  def completed_by?(user)
    challenge_completions.exists?(user: user)
  end
  
  # Complete challenge for user
  def complete_for(user)
    return false if completed_by?(user) && !repeatable?
    
    completion = challenge_completions.create!(
      user: user,
      completed_at: Time.current
    )
    
    # Award points
    seasonal_event.award_points(user, points_reward, "Challenge: #{name}")
    
    # Award bonus rewards
    award_bonus_rewards(user)
    
    # Increment completion count
    increment!(:completion_count)
    
    # Notify user
    notify_completion(user)
    
    completion
  end
  
  # Get progress for user
  def progress_for(user)
    case challenge_type.to_sym
    when :purchase
      calculate_purchase_progress(user)
    when :social
      calculate_social_progress(user)
    when :engagement
      calculate_engagement_progress(user)
    when :collection
      calculate_collection_progress(user)
    when :time_limited
      calculate_time_limited_progress(user)
    else
      0
    end
  end
  
  private
  
  def award_bonus_rewards(user)
    return unless bonus_coins > 0
    user.increment!(:coins, bonus_coins)
  end
  
  def notify_completion(user)
    Notification.create!(
      recipient: user,
      notifiable: self,
      notification_type: 'challenge_completed',
      title: "Challenge Completed: #{name}!",
      message: description,
      data: { points: points_reward, bonus_coins: bonus_coins }
    )
  end
  
  def calculate_purchase_progress(user)
    # Implementation depends on challenge requirements
    0
  end
  
  def calculate_social_progress(user)
    # Implementation depends on challenge requirements
    0
  end
  
  def calculate_engagement_progress(user)
    # Implementation depends on challenge requirements
    0
  end
  
  def calculate_collection_progress(user)
    # Implementation depends on challenge requirements
    0
  end
  
  def calculate_time_limited_progress(user)
    # Implementation depends on challenge requirements
    0
  end
end

