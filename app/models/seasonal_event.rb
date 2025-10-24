class SeasonalEvent < ApplicationRecord
  has_many :event_challenges, dependent: :destroy
  has_many :event_participations, dependent: :destroy
  has_many :participants, through: :event_participations, source: :user
  has_many :event_rewards, dependent: :destroy
  
  validates :name, presence: true, length: { maximum: 100 }
  validates :event_type, presence: true, inclusion: { in: event_types.keys }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validate :ends_after_starts

  private

  def ends_after_starts
    return unless starts_at && ends_at
    errors.add(:ends_at, "must be after starts_at") if ends_at <= starts_at
  end
  
  enum event_type: {
    holiday: 0,
    seasonal: 1,
    anniversary: 2,
    flash_sale: 3,
    community: 4,
    special: 5
  }
  
  enum status: {
    upcoming: 0,
    active: 1,
    ended: 2
  }
  
  # Scopes
  scope :active_events, -> { where(status: :active).where('starts_at <= ? AND ends_at >= ?', Time.current, Time.current) }
  scope :upcoming_events, -> { where(status: :upcoming).where('starts_at > ?', Time.current) }
  scope :by_type, ->(type) { where(event_type: type) }
  
  # Get user's participation
  def participation_for(user)
    event_participations.find_by(user: user)
  end

  # Get active challenges
  def active_challenges
    event_challenges.where(active: true)
  end

  # Check if event is currently active
  def currently_active?
    active? && starts_at <= Time.current && ends_at >= Time.current
  end

  # Days remaining
  def days_remaining
    return 0 unless currently_active?
    ((ends_at - Time.current) / 1.day).ceil
  end

  # Delegated methods to services
  def start!
    SeasonalEventLifecycleService.start_event(self)
  rescue => e
    Rails.logger.error("Failed to start event #{id}: #{e.message}")
    false
  end

  def end!
    SeasonalEventLifecycleService.end_event(self)
  rescue => e
    Rails.logger.error("Failed to end event #{id}: #{e.message}")
    false
  end

  def join(user)
    SeasonalEventLifecycleService.join_event(self, user)
  rescue => e
    Rails.logger.error("Failed to join event #{id} for user #{user.id}: #{e.message}")
    false
  end

  def award_points(user, points, reason = nil)
    SeasonalEventParticipationService.new(self).award_points(user, points, reason)
  rescue => e
    Rails.logger.error("Failed to award points for event #{id}, user #{user.id}: #{e.message}")
    false
  end

  def leaderboard(limit: 100)
    SeasonalEventLeaderboardService.new(self).leaderboard(limit: limit)
  rescue => e
    Rails.logger.error("Failed to get leaderboard for event #{id}: #{e.message}")
    []
  end

  def user_rank(user)
    SeasonalEventLeaderboardService.new(self).user_rank(user)
  rescue => e
    Rails.logger.error("Failed to get user rank for event #{id}, user #{user.id}: #{e.message}")
    nil
  end

  def statistics
    SeasonalEventPresenter.new(self).statistics
  rescue => e
    Rails.logger.error("Failed to get statistics for event #{id}: #{e.message}")
    {}
  end
  
  
end

