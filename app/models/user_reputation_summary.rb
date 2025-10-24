# frozen_string_literal: true

# Read Model: Optimized for fast user reputation queries
# Denormalized view of user reputation state for efficient reads
class UserReputationSummary < ApplicationRecord
  # Table configuration
  self.table_name = 'user_reputation_summaries'
  self.primary_key = 'user_id'

  # Relationships
  belongs_to :user, foreign_key: 'user_id'

  # Enums for type safety
  enum reputation_level: {
    restricted: 'restricted',
    probation: 'probation',
    regular: 'regular',
    trusted: 'trusted',
    exemplary: 'exemplary'
  }

  # Validations
  validates :user_id, presence: true, uniqueness: true
  validates :total_score, numericality: { greater_than_or_equal_to: -1000, less_than_or_equal_to: 10000 }
  validates :reputation_level, presence: true
  validates :events_count, numericality: { greater_than_or_equal_to: 0 }

  # Scopes for efficient querying
  scope :active_users, -> { where('last_activity_at >= ?', 30.days.ago) }
  scope :high_reputation, -> { where('total_score >= 100') }
  scope :by_level, ->(level) { where(reputation_level: level) }
  scope :top_scorers, ->(limit = 10) { order(total_score: :desc).limit(limit) }
  scope :recently_active, -> { order(last_activity_at: :desc) }

  # Optimized indexes (to be added via migration)
  # add_index :user_reputation_summaries, :total_score
  # add_index :user_reputation_summaries, :reputation_level
  # add_index :user_reputation_summaries, :last_activity_at
  # add_index :user_reputation_summaries, [:reputation_level, :total_score]

  # Instance methods
  def level_object
    @level_object ||= ReputationLevel.new(reputation_level)
  end

  def can_post_content?
    level_object.can_post_content?
  end

  def can_moderate?
    level_object.can_moderate?
  end

  def can_access_premium_features?
    level_object.can_access_premium_features?
  end

  def level_progress
    level_obj = level_object
    return { percentage: 0, points_to_next: 0 } if level_obj.name == 'exemplary'

    current_min = level_obj.min_score
    current_max = level_obj.max_score
    next_level = ReputationLevel.all_levels[ReputationLevel.all_levels.index(level_obj.name.to_sym) + 1]

    return { percentage: 100, points_to_next: 0 } unless next_level

    next_level_obj = ReputationLevel.new(next_level.to_s)
    progress_range = current_max - current_min
    current_progress = total_score - current_min
    percentage = [(current_progress.to_f / progress_range * 100), 100].min

    {
      percentage: percentage.round(1),
      points_to_next: next_level_obj.min_score - total_score
    }
  end

  def reputation_velocity(days = 7)
    # Calculate rate of reputation change
    recent_events = UserReputationEvent.where(user_id: user_id)
                                      .where('created_at >= ?', days.days.ago)

    return 0.0 if recent_events.empty?

    total_change = recent_events.sum(:points_change)
    (total_change.to_f / days).round(2)
  end

  def consistency_score(days = 30)
    # Calculate how consistent reputation gains are
    events = UserReputationEvent.where(user_id: user_id)
                               .where('created_at >= ?', days.days.ago)

    return 50.0 if events.empty?

    changes = events.pluck(:points_change)
    mean = changes.sum.to_f / changes.size
    variance = changes.sum { |change| (change - mean) ** 2 } / changes.size

    # Lower variance = higher consistency (0-100 scale)
    consistency = [100 - Math.sqrt(variance), 0].max
    consistency.round(1)
  end

  def risk_score
    # Calculate risk score based on recent negative events and patterns
    recent_losses = UserReputationEvent.where(user_id: user_id)
                                      .where('points_change < 0')
                                      .where('created_at >= ?', 30.days.ago)

    return 0 if recent_losses.empty?

    # Base risk on frequency and severity of losses
    frequency_factor = [recent_losses.count / 30.0, 1.0].min
    severity_factor = recent_losses.sum(:points_change).abs / 100.0

    risk = (frequency_factor + severity_factor) / 2 * 100
    [risk, 100].min.round(1)
  end

  def achievements
    achievements = []

    if total_score >= 1000
      achievements << 'Reputation Master'
    end

    if total_score >= 500
      achievements << 'Trusted Contributor'
    end

    if total_score >= 100
      achievements << 'Rising Star'
    end

    if consistency_score >= 80
      achievements << 'Consistency King'
    end

    if events_count >= 100 && risk_score <= 20
      achievements << 'Reliable Member'
    end

    achievements
  end

  # Class methods for bulk operations and analytics
  def self.refresh_for_user(user_id)
    events = UserReputationEvent.where(user_id: user_id)

    summary = find_or_initialize_by(user_id: user_id)
    summary.update!(
      total_score: events.sum(:points_change),
      events_count: events.count,
      last_activity_at: events.maximum(:created_at),
      reputation_level: ReputationLevel.from_score(events.sum(:points_change)).to_s,
      updated_at: Time.current
    )

    summary
  end

  def self.refresh_all
    # Refresh all summaries in batches for performance
    user_ids = UserReputationEvent.distinct.pluck(:user_id)

    updated_count = 0
    user_ids.each do |user_id|
      begin
        refresh_for_user(user_id)
        updated_count += 1
      rescue StandardError => e
        Rails.logger.error("Failed to refresh reputation summary for user #{user_id}: #{e.message}")
      end
    end

    updated_count
  end

  def self.distribution_by_level
    group(:reputation_level).count
  end

  def self.average_score_by_level
    group(:reputation_level).average(:total_score)
  end

  def self.top_users_by_score(limit = 10)
    order(total_score: :desc).limit(limit)
  end

  def self.users_by_risk_threshold(threshold = 50)
    where('risk_score >= ?', threshold)
  end

  def self.inactive_users(days = 30)
    where('last_activity_at < ?', days.days.ago)
  end

  # Projection handler for event-driven updates
  def self.handle_reputation_event(event)
    case event
    when ReputationGainedEvent, ReputationLostEvent, ReputationResetEvent
      refresh_for_user(event.user_id)
    when ReputationLevelChangedEvent
      refresh_for_user(event.user_id)
    end
  end

  private

  # Calculate risk score based on recent activity patterns
  def calculate_risk_score
    # Implementation moved to instance method for clarity
  end
end