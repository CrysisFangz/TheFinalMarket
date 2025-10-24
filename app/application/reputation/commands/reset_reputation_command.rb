# frozen_string_literal: true

# Command: Reset user reputation to zero or specified value
# Administrative command for reputation management with full audit trail
class ResetReputationCommand
  include CommandPattern

  attr_reader :user_id, :admin_user_id, :reset_reason, :new_score

  def initialize(user_id:, admin_user_id:, reset_reason:, new_score: 0)
    @user_id = user_id
    @admin_user_id = admin_user_id
    @reset_reason = reset_reason
    @new_score = new_score

    validate!
  end

  def execute
    validate_execution!

    ActiveRecord::Base.transaction do
      user = User.find(user_id)
      previous_score = user.reputation_score

      # Create reset event
      event = create_reset_event(previous_score)
      store_event(event)
      update_user_reputation(event, previous_score)
      publish_event(event)

      # Update user level based on new score
      update_user_level(user)

      # Create admin audit log
      create_admin_audit_log(event)

      event
    end
  rescue StandardError => e
    Rails.logger.error("Failed to reset reputation for user #{user_id}: #{e.message}")
    raise CommandExecutionError, "Reputation reset failed: #{e.message}"
  end

  private

  def validate!
    raise ValidationError, 'User ID is required' unless user_id.present?
    raise ValidationError, 'Admin User ID is required' unless admin_user_id.present?
    raise ValidationError, 'Reset reason is required' unless reset_reason.present?
    raise ValidationError, 'Invalid new score' unless new_score >= -1000 && new_score <= 1000
  end

  def validate_execution!
    user = User.find_by(id: user_id)
    raise ValidationError, 'User not found' unless user

    admin = User.find_by(id: admin_user_id)
    raise ValidationError, 'Admin user not found' unless admin
    raise ValidationError, 'Insufficient admin privileges' unless admin_can_reset?(admin)

    # Check for recent resets to prevent abuse
    recent_resets = UserReputationEvent.where(user_id: user_id)
                                      .where(event_type: :reputation_reset)
                                      .where('created_at >= ?', 24.hours.ago)
                                      .count

    raise ValidationError, 'Too many recent resets' if recent_resets >= 2
  end

  def create_reset_event(previous_score)
    aggregate_id = "user_reputation_#{user_id}"

    ReputationResetEvent.new(
      aggregate_id,
      user_id: user_id,
      previous_score: previous_score,
      reset_reason: reset_reason,
      admin_user_id: admin_user_id
    )
  end

  def store_event(event)
    event_store = EventStore.new
    event_store.append_events(event.aggregate_id, [event])
  end

  def update_user_reputation(event, previous_score)
    # Create reset record in read model
    UserReputationEvent.create!(
      user_id: event.user_id,
      event_type: :reputation_reset,
      points_change: new_score - previous_score,
      reason: event.reset_reason,
      admin_user_id: event.admin_user_id,
      context_data: {
        previous_score: previous_score,
        new_score: new_score,
        reset_type: determine_reset_type(previous_score)
      }
    )
  end

  def publish_event(event)
    EventPublisher.publish('reputation.events', event)
    EventPublisher.publish('admin.audit', event)
  end

  def update_user_level(user)
    new_level = ReputationLevel.from_score(new_score)
    user.update!(reputation_level: new_level)
  end

  def create_admin_audit_log(event)
    AdminAuditLog.create!(
      admin_user_id: admin_user_id,
      action_type: 'reputation_reset',
      target_user_id: user_id,
      details: {
        previous_score: event.previous_score,
        new_score: new_score,
        reason: reset_reason,
        event_id: event.event_id
      },
      ip_address: Current.user_ip,
      user_agent: Current.user_agent
    )
  end

  def admin_can_reset?(admin)
    admin.has_role?(:admin) || admin.has_role?(:moderator)
  end

  def determine_reset_type(previous_score)
    if previous_score > 100 && new_score <= 0
      :disciplinary_reset
    elsif previous_score < -50 && new_score >= 0
      :forgiveness_reset
    else
      :administrative_reset
    end
  end
end