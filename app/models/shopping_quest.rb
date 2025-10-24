class ShoppingQuest < ApplicationRecord
  include EventSourcing::Entity

  has_many :quest_objectives, dependent: :destroy
  has_many :quest_participations, dependent: :destroy
  has_many :participants, through: :quest_participations, source: :user

  validates :name, presence: true, length: { maximum: 255 }
  validates :quest_type, presence: true, inclusion: { in: quest_types.keys }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :difficulty, inclusion: { in: difficulties.keys }, allow_nil: true
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validates :required_level, numericality: { greater_than: 0 }, allow_nil: true
  validates :reward_coins, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :reward_experience, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :reward_tokens, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :ends_after_starts

  enum quest_type: {
    daily: 0,
    weekly: 1,
    monthly: 2,
    seasonal: 3,
    special_event: 4,
    story_quest: 5
  }

  enum status: {
    draft: 0,
    active: 1,
    completed: 2,
    expired: 3
  }

  enum difficulty: {
    beginner: 0,
    intermediate: 1,
    advanced: 2,
    expert: 3
  }

  # Optimized scopes with eager loading
  scope :active_quests, -> { where(status: :active).where('starts_at <= ? AND ends_at >= ?', Time.current, Time.current) }
  scope :by_type, ->(type) { where(quest_type: type) }
  scope :by_difficulty, ->(difficulty) { where(difficulty: difficulty) }

  # Event sourcing integration
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_deleted_event

  def publish_created_event
    EventSourcing::EventStore.append_event(
      self,
      'quest_created',
      { name: name, quest_type: quest_type, status: status },
      {}
    )
  end

  def publish_updated_event
    if saved_changes.any?
      EventSourcing::EventStore.append_event(
        self,
        'quest_updated',
        saved_changes,
        {}
      )
    end
  end

  def publish_deleted_event
    EventSourcing::EventStore.append_event(
      self,
      'quest_deleted',
      { id: id, name: name },
      {}
    )
  end

  # Optimized methods using services
  def can_start?(user)
    active? &&
    starts_at <= Time.current &&
    ends_at >= Time.current &&
    !participants.include?(user) &&
    meets_requirements?(user)
  end

  def start_for(user)
    service = QuestParticipationService.new(self, user)
    result = service.start_quest
    result.success? ? result.value : false
  end

  def participation_for(user)
    quest_participations.find_by(user: user)
  end

  def check_progress(user)
    service = QuestProgressService.new(self, user)
    result = service.check_progress
    result.success? ? result.value : nil
  end

  def complete_quest_for(user)
    service = QuestCompletionService.new(self, user)
    result = service.complete_quest
    result.success? ? result.value : nil
  end

  def leaderboard(limit: 10)
    service = QuestLeaderboardService.new(self, limit: limit)
    result = service.leaderboard
    result.success? ? result.value : []
  end

  def statistics
    service = QuestStatisticsService.new(self)
    result = service.statistics
    result.success? ? result.value : {}
  end

  # Cached methods for performance
  def cached_statistics
    Rails.cache.fetch("quest:#{id}:statistics", expires_in: 1.hour) do
      statistics
    end
  end

  def cached_leaderboard(limit: 10)
    Rails.cache.fetch("quest:#{id}:leaderboard:#{limit}", expires_in: 15.minutes) do
      leaderboard(limit: limit)
    end
  end

    private

  def meets_requirements?(user)
    return true if required_level.nil?
    user.level >= required_level
  end

  def ends_after_starts
    return unless starts_at && ends_at
    errors.add(:ends_at, "must be after starts_at") if ends_at <= starts_at
  end
end</search>
</search_and_replace>

