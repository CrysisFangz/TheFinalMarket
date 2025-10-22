# frozen_string_literal: true

# Domain Event: Represents a reputation points gain for a user
# Follows event sourcing pattern with immutable state and audit trail
class ReputationGainedEvent
  include ActiveModel::Model
  include ActiveEvent::Event

  # Event metadata
  attribute :event_id, :string
  attribute :aggregate_id, :string
  attribute :timestamp, :datetime
  attribute :version, :integer
  attribute :metadata, default: {}

  # Domain data
  attribute :user_id, :integer
  attribute :points_gained, :integer
  attribute :reason, :string
  attribute :source_type, :string # 'purchase', 'review', 'referral', etc.
  attribute :source_id, :string # ID of the source entity
  attribute :reputation_multiplier, :decimal, default: 1.0
  attribute :context_data, default: {}

  validates :user_id, :points_gained, :reason, presence: true
  validates :points_gained, numericality: { greater_than: 0 }
  validates :reputation_multiplier, numericality: { greater_than_or_equal_to: 0.1, less_than_or_equal_to: 5.0 }

  # Initialize with aggregate and domain data
  def initialize(aggregate_id, user_id:, points_gained:, reason:, source_type: nil, source_id: nil,
                 reputation_multiplier: 1.0, context_data: {}, event_id: nil, timestamp: nil, version: nil, metadata: {})
    @aggregate_id = aggregate_id
    @user_id = user_id
    @points_gained = points_gained
    @reason = reason
    @source_type = source_type
    @source_id = source_id
    @reputation_multiplier = reputation_multiplier
    @context_data = context_data
    @event_id = event_id || SecureRandom.uuid
    @timestamp = timestamp || Time.current
    @version = version
    @metadata = metadata

    super()
  end

  # Calculate actual points to award (considering multiplier)
  def actual_points_gained
    (points_gained * reputation_multiplier).round
  end

  # Event type for storage and routing
  def event_type
    'ReputationGainedEvent'
  end

  # Serialize for storage
  def event_data
    {
      user_id: user_id,
      points_gained: points_gained,
      reason: reason,
      source_type: source_type,
      source_id: source_id,
      reputation_multiplier: reputation_multiplier,
      context_data: context_data
    }
  end

  # Human readable description
  def description
    "User #{user_id} gained #{actual_points_gained} reputation points for: #{reason}"
  end
end

# Domain Event: Represents a reputation points loss for a user
class ReputationLostEvent
  include ActiveModel::Model
  include ActiveEvent::Event

  attribute :event_id, :string
  attribute :aggregate_id, :string
  attribute :timestamp, :datetime
  attribute :version, :integer
  attribute :metadata, default: {}

  attribute :user_id, :integer
  attribute :points_lost, :integer
  attribute :reason, :string
  attribute :violation_type, :string # 'spam', 'harassment', 'fraud', etc.
  attribute :severity_level, :string # 'low', 'medium', 'high', 'critical'
  attribute :context_data, default: {}

  validates :user_id, :points_lost, :reason, :violation_type, presence: true
  validates :points_lost, numericality: { greater_than: 0 }
  validates :severity_level, inclusion: { in: %w[low medium high critical] }

  def initialize(aggregate_id, user_id:, points_lost:, reason:, violation_type:, severity_level: 'medium',
                 context_data: {}, event_id: nil, timestamp: nil, version: nil, metadata: {})
    @aggregate_id = aggregate_id
    @user_id = user_id
    @points_lost = points_lost
    @reason = reason
    @violation_type = violation_type
    @severity_level = severity_level
    @context_data = context_data
    @event_id = event_id || SecureRandom.uuid
    @timestamp = timestamp || Time.current
    @version = version
    @metadata = metadata

    super()
  end

  def event_type
    'ReputationLostEvent'
  end

  def event_data
    {
      user_id: user_id,
      points_lost: points_lost,
      reason: reason,
      violation_type: violation_type,
      severity_level: severity_level,
      context_data: context_data
    }
  end

  def description
    "User #{user_id} lost #{points_lost} reputation points for #{violation_type}: #{reason}"
  end
end

# Domain Event: Represents a complete reputation reset for a user
class ReputationResetEvent
  include ActiveModel::Model
  include ActiveEvent::Event

  attribute :event_id, :string
  attribute :aggregate_id, :string
  attribute :timestamp, :datetime
  attribute :version, :integer
  attribute :metadata, default: {}

  attribute :user_id, :integer
  attribute :previous_score, :integer
  attribute :reset_reason, :string
  attribute :admin_user_id, :integer
  attribute :context_data, default: {}

  validates :user_id, :previous_score, :reset_reason, :admin_user_id, presence: true

  def initialize(aggregate_id, user_id:, previous_score:, reset_reason:, admin_user_id:,
                 context_data: {}, event_id: nil, timestamp: nil, version: nil, metadata: {})
    @aggregate_id = aggregate_id
    @user_id = user_id
    @previous_score = previous_score
    @reset_reason = reset_reason
    @admin_user_id = admin_user_id
    @context_data = context_data
    @event_id = event_id || SecureRandom.uuid
    @timestamp = timestamp || Time.current
    @version = version
    @metadata = metadata

    super()
  end

  def event_type
    'ReputationResetEvent'
  end

  def event_data
    {
      user_id: user_id,
      previous_score: previous_score,
      reset_reason: reset_reason,
      admin_user_id: admin_user_id,
      context_data: context_data
    }
  end

  def description
    "User #{user_id} reputation reset from #{previous_score} by admin #{admin_user_id}: #{reset_reason}"
  end
end

# Domain Event: Represents a reputation level change for a user
class ReputationLevelChangedEvent
  include ActiveModel::Model
  include ActiveEvent::Event

  attribute :event_id, :string
  attribute :aggregate_id, :string
  attribute :timestamp, :datetime
  attribute :version, :integer
  attribute :metadata, default: {}

  attribute :user_id, :integer
  attribute :old_level, :string
  attribute :new_level, :string
  attribute :score_threshold, :integer
  attribute :trigger_event_id, :string
  attribute :context_data, default: {}

  validates :user_id, :old_level, :new_level, :score_threshold, presence: true
  validates :old_level, :new_level, inclusion: { in: %w[restricted probation regular trusted exemplary] }

  def initialize(aggregate_id, user_id:, old_level:, new_level:, score_threshold:, trigger_event_id: nil,
                 context_data: {}, event_id: nil, timestamp: nil, version: nil, metadata: {})
    @aggregate_id = aggregate_id
    @user_id = user_id
    @old_level = old_level
    @new_level = new_level
    @score_threshold = score_threshold
    @trigger_event_id = trigger_event_id
    @context_data = context_data
    @event_id = event_id || SecureRandom.uuid
    @timestamp = timestamp || Time.current
    @version = version
    @metadata = metadata

    super()
  end

  def event_type
    'ReputationLevelChangedEvent'
  end

  def event_data
    {
      user_id: user_id,
      old_level: old_level,
      new_level: new_level,
      score_threshold: score_threshold,
      trigger_event_id: trigger_event_id,
      context_data: context_data
    }
  end

  def description
    "User #{user_id} leveled up from #{old_level} to #{new_level} at score #{score_threshold}"
  end

  def level_up?
    ReputationLevel.new(new_level).rank > ReputationLevel.new(old_level).rank
  end

  def level_down?
    ReputationLevel.new(new_level).rank < ReputationLevel.new(old_level).rank
  end
end

# Value Object: Represents reputation level with ranking and permissions
class ReputationLevel
  attr_reader :name, :rank, :min_score, :max_score, :permissions

  def initialize(name)
    @name = name.to_s
    @rank = level_rankings[name.to_sym]
    @min_score, @max_score = level_score_ranges[name.to_sym]
    @permissions = level_permissions[name.to_sym] || []
  end

  def self.all_levels
    %i[restricted probation regular trusted exemplary]
  end

  def self.from_score(score)
    all_levels.find do |level|
      range = level_score_ranges[level]
      score >= range.first && (range.last.nil? || score <= range.last)
    end || :restricted
  end

  def allows?(permission)
    permissions.include?(permission.to_sym)
  end

  def can_post_content?
    allows?(:post_content)
  end

  def can_moderate?
    allows?(:moderate_content)
  end

  def can_access_premium_features?
    allows?(:premium_features)
  end

  private

  def level_rankings
    {
      restricted: 1,
      probation: 2,
      regular: 3,
      trusted: 4,
      exemplary: 5
    }
  end

  def level_score_ranges
    {
      restricted: [-Float::INFINITY, -50],
      probation: [-49, 0],
      regular: [1, 100],
      trusted: [101, 500],
      exemplary: [501, Float::INFINITY]
    }
  end

  def level_permissions
    {
      restricted: [],
      probation: [:read_content],
      regular: [:read_content, :post_content, :comment],
      trusted: [:read_content, :post_content, :comment, :premium_features, :early_access],
      exemplary: [:read_content, :post_content, :comment, :premium_features, :early_access, :moderate_content, :priority_support]
    }
  end
end

# Enhanced ActiveRecord model for storing reputation events
# Optimized for high-performance reputation queries with proper indexing
class UserReputationEvent < ApplicationRecord
  # Table name and primary key
  self.table_name = 'user_reputation_events'
  self.primary_key = 'id'

  # Relationships
  belongs_to :user, class_name: 'User', foreign_key: 'user_id'

  # Enums for better type safety
  enum event_type: {
    reputation_gained: 'reputation_gained',
    reputation_lost: 'reputation_lost',
    reputation_reset: 'reputation_reset',
    reputation_level_changed: 'reputation_level_changed'
  }

  enum reputation_level: {
    restricted: 'restricted',
    probation: 'probation',
    regular: 'regular',
    trusted: 'trusted',
    exemplary: 'exemplary'
  }

  # Validations
  validates :user_id, :event_type, :points_change, presence: true
  validates :points_change, numericality: { greater_than_or_equal_to: -1000, less_than_or_equal_to: 1000 }
  validates :reason, presence: true, length: { maximum: 500 }
  validates :source_type, length: { maximum: 100 }, allow_nil: true
  validates :violation_type, inclusion: { in: %w[spam harassment fraud scam inappropriate_content] }, allow_nil: true
  validates :severity_level, inclusion: { in: %w[low medium high critical] }, allow_nil: true

  # Scopes for efficient querying
  scope :recent, ->(days = 30) { where('created_at >= ?', days.days.ago) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :gains, -> { where('points_change > 0') }
  scope :losses, -> { where('points_change < 0') }
  scope :by_event_type, ->(type) { where(event_type: type) }
  scope :by_level, ->(level) { where(reputation_level: level) }
  scope :high_impact, -> { where('ABS(points_change) >= 50') }

  # Optimized indexes (these would be added via migration)
  # add_index :user_reputation_events, [:user_id, :created_at]
  # add_index :user_reputation_events, [:event_type, :created_at]
  # add_index :user_reputation_events, [:reputation_level, :user_id]
  # add_index :user_reputation_events, :source_type
  # add_index :user_reputation_events, :points_change

  # Instance methods
  def gain?
    points_change.positive?
  end

  def loss?
    points_change.negative?
  end

  def high_impact?
    points_change.abs >= 50
  end

  def reputation_level_object
    @reputation_level_object ||= ReputationLevel.new(reputation_level)
  end

  def description
    case event_type.to_sym
    when :reputation_gained
      "Gained #{points_change.abs} points: #{reason}"
    when :reputation_lost
      "Lost #{points_change.abs} points (#{violation_type}): #{reason}"
    when :reputation_reset
      "Reputation reset: #{reason}"
    when :reputation_level_changed
      "Level changed from #{previous_level} to #{reputation_level}: #{reason}"
    else
      "Reputation event: #{reason}"
    end
  end

  # Class methods for analytics and reporting
  def self.total_points_for_user(user_id)
    where(user_id: user_id).sum(:points_change)
  end

  def self.average_points_change
    average(:points_change).to_f
  end

  def self.reputation_distribution
    group(:reputation_level).count
  end

  def self.top_contributors(limit = 10)
    gains.joins(:user)
         .select('users.*, SUM(points_change) as total_points')
         .group('users.id')
         .order('total_points DESC')
         .limit(limit)
  end

  # Circuit breaker integration for resilience
  def self.with_reputation_circuit_breaker
    ReputationCircuitBreaker.execute do
      yield self
    end
  end

  private

  # Custom validation methods
  def validate_points_change
    if event_type == 'reputation_lost' && points_change.positive?
      errors.add(:points_change, 'must be negative for reputation loss events')
    elsif event_type == 'reputation_gained' && points_change.negative?
      errors.add(:points_change, 'must be positive for reputation gain events')
    end
  end

  def validate_violation_data
    if event_type == 'reputation_lost' && violation_type.blank?
      errors.add(:violation_type, 'is required for reputation loss events')
    end
  end
end

# Circuit Breaker for reputation operations
class ReputationCircuitBreaker
  include CircuitBreakerPattern

  def self.execute
    circuit_breaker = CircuitBreaker.new(
      failure_threshold: 5,
      recovery_timeout: 30.seconds,
      expected_exception: [ActiveRecord::ConnectionTimeoutError, ActiveRecord::StatementInvalid]
    )

    circuit_breaker.execute do
      yield
    end
  end
end