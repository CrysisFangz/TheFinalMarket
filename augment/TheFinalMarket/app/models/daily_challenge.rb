class DailyChallenge < ApplicationRecord
  has_many :user_daily_challenges, dependent: :destroy
  has_many :users, through: :user_daily_challenges
  
  enum challenge_type: {
    browse_products: 0,
    add_to_wishlist: 1,
    make_purchase: 2,
    leave_review: 3,
    list_product: 4,
    share_product: 5,
    complete_profile: 6,
    invite_friend: 7,
    participate_in_discussion: 8,
    watch_live_event: 9
  }
  
  enum difficulty: {
    easy: 0,
    medium: 1,
    hard: 2,
    expert: 3
  }
  
  validates :title, presence: true
  validates :description, presence: true
  validates :target_value, numericality: { greater_than: 0 }
  validates :reward_points, numericality: { greater_than_or_equal_to: 0 }
  validates :active_date, presence: true
  
  scope :active, -> { where(active: true) }
  scope :for_date, ->(date) { where(active_date: date.beginning_of_day..date.end_of_day) }
  scope :today, -> { for_date(Date.current) }
  scope :upcoming, -> { where('active_date > ?', Date.current) }
  scope :past, -> { where('active_date < ?', Date.current) }
  
  # Generate daily challenges for a specific date
  def self.generate_for_date(date = Date.current)
    return if for_date(date).exists?
    
    challenges = [
      {
        title: "Window Shopper",
        description: "Browse 10 different products",
        challenge_type: :browse_products,
        target_value: 10,
        reward_points: 50,
        reward_coins: 10,
        difficulty: :easy
      },
      {
        title: "Wishlist Builder",
        description: "Add 3 items to your wishlist",
        challenge_type: :add_to_wishlist,
        target_value: 3,
        reward_points: 75,
        reward_coins: 15,
        difficulty: :easy
      },
      {
        title: "Review Master",
        description: "Leave a detailed review on a purchased item",
        challenge_type: :leave_review,
        target_value: 1,
        reward_points: 100,
        reward_coins: 25,
        difficulty: :medium
      },
      {
        title: "Social Butterfly",
        description: "Share 2 products with friends",
        challenge_type: :share_product,
        target_value: 2,
        reward_points: 60,
        reward_coins: 12,
        difficulty: :easy
      }
    ]
    
    # Randomly select 3 challenges for the day
    selected_challenges = challenges.sample(3)
    
    selected_challenges.each do |challenge_data|
      create!(
        challenge_data.merge(
          active_date: date,
          expires_at: date.end_of_day,
          active: true
        )
      )
    end
  end
  
  # Check if user completed this challenge
  def completed_by?(user)
    user_daily_challenges.exists?(user: user, completed: true)
  end
  
  # Get user's progress on this challenge
  def progress_for(user)
    user_challenge = user_daily_challenges.find_or_initialize_by(user: user)
    user_challenge.current_value || 0
  end
  
  # Update user's progress
  def update_progress(user, increment = 1)
    user_challenge = user_daily_challenges.find_or_create_by!(user: user)
    user_challenge.increment!(:current_value, increment)
    
    # Check if challenge is completed
    if user_challenge.current_value >= target_value && !user_challenge.completed?
      complete_challenge(user, user_challenge)
    end
    
    user_challenge
  end
  
  # Get completion percentage for user
  def completion_percentage(user)
    progress = progress_for(user)
    ((progress.to_f / target_value) * 100).round(2).clamp(0, 100)
  end
  
  private
  
  def complete_challenge(user, user_challenge)
    user_challenge.update!(
      completed: true,
      completed_at: Time.current
    )
    
    # Award rewards
    user.increment!(:points, reward_points) if reward_points > 0
    user.increment!(:coins, reward_coins) if reward_coins > 0
    
    # Update streak
    user.update_challenge_streak!
    
    # Send notification
    Notification.create!(
      recipient: user,
      notifiable: self,
      notification_type: 'challenge_completed',
      title: "Challenge Completed: #{title}!",
      message: "You've earned #{reward_points} points and #{reward_coins} coins!",
      data: {
        points: reward_points,
        coins: reward_coins,
        difficulty: difficulty
      }
    )
    
    # Broadcast completion
    broadcast_completion(user)
  end
  
  def broadcast_completion(user)
    broadcast_replace_to(
      "user_#{user.id}_challenges",
      target: "challenge_#{id}",
      partial: "daily_challenges/completed_challenge",
      locals: { challenge: self, user: user }
    )
  end
end

