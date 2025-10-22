# frozen_string_literal: true

# Command: Gain reputation points for a user
# Handles the business logic for reputation gains with validation and event publishing
class GainReputationCommand
  include CommandPattern

  attr_reader :user_id, :points, :reason, :source_type, :source_id, :multiplier

  # Initialize command with validation
  def initialize(user_id:, points:, reason:, source_type: nil, source_id: nil, multiplier: 1.0)
    @user_id = user_id
    @points = points
    @reason = reason
    @source_type = source_type
    @source_id = source_id
    @multiplier = multiplier

    validate!
  end

  # Execute the reputation gain
  def execute
    validate_execution!

    ActiveRecord::Base.transaction do
      # Create and store domain event
      event = create_reputation_event
      store_event(event)

      # Update read model
      update_user_reputation(event)

      # Publish to event bus for projections
      publish_event(event)

      # Check for level changes
      check_level_change(event)

      event
    end
  rescue ActiveRecord::RecordInvalid => e
    raise ValidationError, "Invalid reputation gain: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("Failed to gain reputation for user #{user_id}: #{e.message}")
    raise CommandExecutionError, "Reputation gain failed: #{e.message}"
  end

  private

  def validate!
    raise ValidationError, 'User ID is required' unless user_id.present?
    raise ValidationError, 'Points must be positive' unless points.positive?
    raise ValidationError, 'Reason is required' unless reason.present?
    raise ValidationError, 'Invalid multiplier' unless multiplier.between?(0.1, 5.0)
    raise ValidationError, 'Invalid source type' if source_type.present? && !valid_source_types.include?(source_type)
  end

  def validate_execution!
    user = User.find_by(id: user_id)
    raise ValidationError, 'User not found' unless user
    raise ValidationError, 'User is restricted' if user.reputation_level == 'restricted'
  end

  def create_reputation_event
    aggregate_id = "user_reputation_#{user_id}"

    ReputationGainedEvent.new(
      aggregate_id,
      user_id: user_id,
      points_gained: points,
      reason: reason,
      source_type: source_type,
      source_id: source_id,
      reputation_multiplier: multiplier
    )
  end

  def store_event(event)
    # Use existing event store infrastructure
    event_store = EventStore.new
    event_store.append_events(event.aggregate_id, [event])
  end

  def update_user_reputation(event)
    # Update the read model for immediate consistency
    UserReputationEvent.create!(
      user_id: event.user_id,
      event_type: :reputation_gained,
      points_change: event.actual_points_gained,
      reason: event.reason,
      source_type: event.source_type,
      source_id: event.source_id,
      reputation_multiplier: event.reputation_multiplier,
      context_data: event.context_data
    )
  end

  def publish_event(event)
    # Publish to message bus for async processing
    EventPublisher.publish('reputation.events', event)
  end

  def check_level_change(event)
    user = User.find(event.user_id)
    new_score = user.reputation_score + event.actual_points_gained
    new_level = ReputationLevel.from_score(new_score)

    return if user.reputation_level.to_sym == new_level

    # Create level change event
    level_change_event = ReputationLevelChangedEvent.new(
      event.aggregate_id,
      user_id: event.user_id,
      old_level: user.reputation_level,
      new_level: new_level.to_s,
      score_threshold: new_score,
      trigger_event_id: event.event_id
    )

    # Store and publish level change
    event_store = EventStore.new
    event_store.append_events(level_change_event.aggregate_id, [level_change_event])
    EventPublisher.publish('reputation.events', level_change_event)

    # Update user level in read model
    user.update!(reputation_level: new_level)
  end

  def valid_source_types
    %w[purchase review referral content_creation moderation_help bug_report]
  end
end