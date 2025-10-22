# frozen_string_literal: true

# Command: Lose reputation points for a user
# Handles reputation penalties with severity assessment and appeal process
class LoseReputationCommand
  include CommandPattern

  attr_reader :user_id, :points, :reason, :violation_type, :severity_level

  def initialize(user_id:, points:, reason:, violation_type:, severity_level: 'medium')
    @user_id = user_id
    @points = points
    @reason = reason
    @violation_type = violation_type
    @severity_level = severity_level

    validate!
  end

  def execute
    validate_execution!

    ActiveRecord::Base.transaction do
      event = create_reputation_loss_event
      store_event(event)
      update_user_reputation(event)
      publish_event(event)
      check_level_change(event)

      # Create appeal record for significant penalties
      create_appeal_record(event) if event.high_severity?

      event
    end
  rescue StandardError => e
    Rails.logger.error("Failed to penalize reputation for user #{user_id}: #{e.message}")
    raise CommandExecutionError, "Reputation penalty failed: #{e.message}"
  end

  private

  def validate!
    raise ValidationError, 'User ID is required' unless user_id.present?
    raise ValidationError, 'Points must be positive' unless points.positive?
    raise ValidationError, 'Reason is required' unless reason.present?
    raise ValidationError, 'Violation type is required' unless violation_type.present?
    raise ValidationError, 'Invalid violation type' unless valid_violation_types.include?(violation_type)
    raise ValidationError, 'Invalid severity level' unless valid_severity_levels.include?(severity_level)
  end

  def validate_execution!
    user = User.find_by(id: user_id)
    raise ValidationError, 'User not found' unless user

    # Check for recent penalties to prevent abuse
    recent_penalties = UserReputationEvent.where(user_id: user_id)
                                         .where('created_at >= ?', 1.hour.ago)
                                         .losses.count

    raise ValidationError, 'Too many recent penalties' if recent_penalties >= 3
  end

  def create_reputation_loss_event
    aggregate_id = "user_reputation_#{user_id}"

    ReputationLostEvent.new(
      aggregate_id,
      user_id: user_id,
      points_lost: points,
      reason: reason,
      violation_type: violation_type,
      severity_level: severity_level
    )
  end

  def store_event(event)
    event_store = EventStore.new
    event_store.append_events(event.aggregate_id, [event])
  end

  def update_user_reputation(event)
    UserReputationEvent.create!(
      user_id: event.user_id,
      event_type: :reputation_lost,
      points_change: -event.points_lost, # Negative for losses
      reason: event.reason,
      violation_type: event.violation_type,
      severity_level: event.severity_level,
      context_data: event.context_data
    )
  end

  def publish_event(event)
    EventPublisher.publish('reputation.events', event)

    # Publish to moderation queue for high severity
    if event.high_severity?
      EventPublisher.publish('moderation.alerts', event)
    end
  end

  def check_level_change(event)
    user = User.find(event.user_id)
    new_score = user.reputation_score - event.points_lost
    new_level = ReputationLevel.from_score(new_score)

    return if user.reputation_level.to_sym == new_level

    level_change_event = ReputationLevelChangedEvent.new(
      event.aggregate_id,
      user_id: event.user_id,
      old_level: user.reputation_level,
      new_level: new_level.to_s,
      score_threshold: new_score,
      trigger_event_id: event.event_id
    )

    event_store = EventStore.new
    event_store.append_events(level_change_event.aggregate_id, [level_change_event])
    EventPublisher.publish('reputation.events', level_change_event)

    user.update!(reputation_level: new_level)
  end

  def create_appeal_record(event)
    UserReputationAppeal.create!(
      user_id: event.user_id,
      event_id: event.event_id,
      points_lost: event.points_lost,
      reason: event.reason,
      violation_type: event.violation_type,
      appeal_deadline: 7.days.from_now,
      status: :pending
    )
  end

  def valid_violation_types
    %w[spam harassment fraud scam inappropriate_content policy_violation]
  end

  def valid_severity_levels
    %w[low medium high critical]
  end
end