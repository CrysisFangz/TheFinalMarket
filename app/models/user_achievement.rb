class UserAchievement < ApplicationRecord
  belongs_to :user
  belongs_to :achievement
  
  validates :user_id, uniqueness: { scope: :achievement_id }, if: -> { achievement&.one_time? }
  validates :progress, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  scope :recent, -> { order(earned_at: :desc) }
  scope :by_category, ->(category) { joins(:achievement).where(achievements: { category: category }) }
  scope :by_tier, ->(tier) { joins(:achievement).where(achievements: { tier: tier }) }
  
  after_create :broadcast_achievement
  
  def completed?
    progress >= 100
  end
  
  def progress_percentage
    "#{progress}%"
  end
  
  private
  
  def broadcast_achievement
    # Broadcast to user's feed
    broadcast_replace_to(
      "user_#{user_id}_achievements",
      target: "achievement_#{id}",
      partial: "achievements/achievement_card",
      locals: { user_achievement: self }
    )
    
    # Trigger confetti animation
    broadcast_append_to(
      "user_#{user_id}_notifications",
      target: "achievement_notifications",
      partial: "achievements/celebration",
      locals: { achievement: achievement }
    )
  end
end

