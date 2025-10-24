class UserDailyChallenge < ApplicationRecord
  belongs_to :user
  belongs_to :daily_challenge

  validates :user_id, uniqueness: { scope: :daily_challenge_id }
  validates :current_value, numericality: { greater_than_or_equal_to: 0 }

  scope :completed, -> { where(completed: true) }
  scope :in_progress, -> { where(completed: false) }
  scope :today, -> { joins(:daily_challenge).merge(DailyChallenge.today) }
  after_save :invalidate_cache

  # Delegate calculations to service for decoupling
  def progress_percentage
    UserDailyChallengeCalculator.progress_percentage(self)
  rescue => e
    Rails.logger.error("Error calculating progress_percentage for UserDailyChallenge #{id}: #{e.message}")
    0.0
  end

  def remaining
    UserDailyChallengeCalculator.remaining(self)
  rescue => e
    Rails.logger.error("Error calculating remaining for UserDailyChallenge #{id}: #{e.message}")
    0
  end
end


  private

  def invalidate_cache
    Rails.cache.delete("user_daily_challenge_progress_#{id}")
    Rails.cache.delete("user_daily_challenge_remaining_#{id}")
  end