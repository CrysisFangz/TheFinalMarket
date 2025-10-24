# frozen_string_literal: true

# Domain Events for Reputation System
require_relative 'reputation_events/reputation_gained_event'
require_relative 'reputation_events/reputation_lost_event'
require_relative 'reputation_events/reputation_reset_event'
require_relative 'reputation_events/reputation_level_changed_event'
require_relative 'reputation_level'

# Enhanced ActiveRecord model for storing reputation events
# Optimized for high-performance reputation queries with proper indexing
class UserReputationEvent < ApplicationRecord
  # Table name and primary key
  self.table_name = 'user_reputation_events'
  self.primary_key = 'id'

  # Relationships
  belongs_to :user, class_name: 'User', foreign_key: 'user_id', counter_cache: :reputation_score

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
  validates :user_id, presence: true
  validates :points_change, presence: true, numericality: { greater_than_or_equal_to: -1000, less_than_or_equal_to: 1000 }
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
  scope :ordered_by_date, -> { order(created_at: :desc) }

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

  # Ensure immutability for certain fields
  before_update :prevent_updates_to_critical_fields

  private

  def prevent_updates_to_critical_fields
    if points_change_changed? || reason_changed?
      errors.add(:base, 'Cannot update points or reason after creation')
      throw(:abort)
    end
  end

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
