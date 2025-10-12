class UserDailyChallenge < ApplicationRecord
  belongs_to :user
  belongs_to :daily_challenge
  
  validates :user_id, uniqueness: { scope: :daily_challenge_id }
  validates :current_value, numericality: { greater_than_or_equal_to: 0 }
  
  scope :completed, -> { where(completed: true) }
  scope :in_progress, -> { where(completed: false) }
  scope :today, -> { joins(:daily_challenge).merge(DailyChallenge.today) }
  
  def progress_percentage
    return 100 if completed?
    ((current_value.to_f / daily_challenge.target_value) * 100).round(2).clamp(0, 100)
  end
  
  def remaining
    [daily_challenge.target_value - current_value, 0].max
  end
end

