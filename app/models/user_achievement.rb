class UserAchievement < ApplicationRecord
  belongs_to :user
  belongs_to :achievement

  validates :user_id, uniqueness: { scope: :achievement_id, message: "User can only earn a one-time achievement once" }, if: -> { achievement&.one_time? }
  validates :progress, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, message: "Progress must be between 0 and 100" }
  validates :earned_at, presence: true, if: :completed?

  # Optimized scopes with includes to prevent N+1 queries
  scope :recent, -> { includes(:achievement, :user).order(earned_at: :desc) }
  scope :by_category, ->(category) { includes(:achievement, :user).joins(:achievement).where(achievements: { category: category }) }
  scope :by_tier, ->(tier) { includes(:achievement, :user).joins(:achievement).where(achievements: { tier: tier }) }
  scope :completed, -> { where('progress >= 100') }

  after_create :broadcast_achievement

  def completed?
    progress >= 100
  end

  def progress_percentage
    "#{progress}%"
  end

  def presenter
    @presenter ||= UserAchievementPresenter.new(self)
  end

  private

  def broadcast_achievement
    AchievementBroadcaster.call(self)
  end
end

