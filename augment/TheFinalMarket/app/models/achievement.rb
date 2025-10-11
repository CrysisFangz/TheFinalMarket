class Achievement < ApplicationRecord
  has_many :user_achievements, dependent: :destroy
  has_many :users, through: :user_achievements
  
  # Achievement categories
  enum category: {
    shopping: 0,
    selling: 1,
    social: 2,
    engagement: 3,
    milestone: 4,
    special: 5
  }
  
  # Achievement tiers
  enum tier: {
    bronze: 0,
    silver: 1,
    gold: 2,
    platinum: 3,
    diamond: 4
  }
  
  # Achievement types
  enum achievement_type: {
    one_time: 0,
    progressive: 1,
    repeatable: 2,
    seasonal: 3,
    hidden: 4
  }
  
  validates :name, presence: true, uniqueness: true
  validates :description, presence: true
  validates :points, numericality: { greater_than_or_equal_to: 0 }
  validates :requirement_value, numericality: { greater_than: 0 }, allow_nil: true
  
  scope :active, -> { where(active: true) }
  scope :visible, -> { where(hidden: false) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_tier, ->(tier) { where(tier: tier) }
  
  # Check if user has earned this achievement
  def earned_by?(user)
    user_achievements.exists?(user: user)
  end
  
  # Award achievement to user
  def award_to(user)
    return if earned_by?(user) && one_time?
    
    user_achievement = user_achievements.create!(
      user: user,
      earned_at: Time.current,
      progress: requirement_value || 100
    )
    
    # Grant rewards
    grant_rewards(user) if user_achievement.persisted?
    
    # Send notification
    notify_user(user)
    
    user_achievement
  end
  
  # Check if user meets requirements
  def check_progress(user)
    return 100 if earned_by?(user) && one_time?
    
    case requirement_type
    when 'purchase_count'
      (user.orders.completed.count.to_f / requirement_value * 100).round(2)
    when 'sales_count'
      (user.sold_orders.completed.count.to_f / requirement_value * 100).round(2)
    when 'review_count'
      (user.reviews.count.to_f / requirement_value * 100).round(2)
    when 'product_count'
      (user.products.active.count.to_f / requirement_value * 100).round(2)
    when 'total_spent'
      (user.total_spent.to_f / requirement_value * 100).round(2)
    when 'total_earned'
      (user.total_earned.to_f / requirement_value * 100).round(2)
    when 'login_streak'
      (user.current_login_streak.to_f / requirement_value * 100).round(2)
    when 'referral_count'
      (user.referrals.count.to_f / requirement_value * 100).round(2)
    else
      0
    end
  end
  
  private
  
  def grant_rewards(user)
    # Award points
    user.increment!(:points, points) if points > 0
    
    # Award coins/currency
    user.increment!(:coins, reward_coins) if reward_coins > 0
    
    # Unlock features
    unlock_features(user) if unlocks.present?
    
    # Grant badges
    user.badges << reward_badge if reward_badge.present?
  end
  
  def unlock_features(user)
    unlocks.each do |feature|
      user.unlocked_features.create!(feature_name: feature)
    end
  end
  
  def notify_user(user)
    Notification.create!(
      recipient: user,
      notifiable: self,
      notification_type: 'achievement_earned',
      title: "Achievement Unlocked: #{name}!",
      message: description,
      data: {
        points: points,
        tier: tier,
        category: category
      }
    )
  end
end

