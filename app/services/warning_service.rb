# WarningService - Enterprise-Grade Warning Management
#
# This service implements sophisticated warning management following the Prime Mandate:
# - Hermetic Decoupling: Isolated warning logic from model callbacks
# - Asymptotic Optimality: Optimized queries and operations
# - Architectural Zenith: Designed for scalability and fault tolerance
# - Antifragility Postulate: Resilient operations with comprehensive error handling

class WarningService
  include Dry::Monads[:result]

  def self.issue_warning(user_id, moderator_id, reason, level, expires_at = nil)
    new.issue_warning(user_id, moderator_id, reason, level, expires_at)
  end

  def self.check_and_apply_suspension(user_id, moderator_id)
    new.check_and_apply_suspension(user_id, moderator_id)
  end

  def issue_warning(user_id, moderator_id, reason, level, expires_at = nil)
    validate_issue_permissions(user_id, moderator_id)
      .bind { |context| validate_warning_data(reason, level) }
      .bind { |data| create_warning_record(user_id, moderator_id, data, expires_at) }
      .bind { |warning| schedule_notification_job(warning) }
      .bind { |warning| schedule_suspension_check_job(warning) }
      .bind { |warning| broadcast_warning_event(warning) }
  end

  def check_and_apply_suspension(user_id, moderator_id)
    validate_suspension_permissions(user_id, moderator_id)
      .bind { |context| retrieve_active_warnings(user_id) }
      .bind { |warnings| evaluate_suspension_criteria(warnings) }
      .bind { |should_suspend| apply_suspension_if_needed(user_id, moderator_id, should_suspend) }
      .bind { |result| broadcast_suspension_event(result) }
  end

  private

  def validate_issue_permissions(user_id, moderator_id)
    user = User.find_by(id: user_id)
    moderator = User.find_by(id: moderator_id)

    return Failure('User not found') unless user.present?
    return Failure('Moderator not found') unless moderator.present?
    return Failure('Moderator lacks permission') unless moderator.moderator? || moderator.admin?

    Success({ user: user, moderator: moderator })
  end

  def validate_warning_data(reason, level)
    errors = []

    errors << 'Reason is required' if reason.blank?
    errors << 'Reason too short' if reason.length < 10
    errors << 'Reason too long' if reason.length > 1000
    errors << 'Invalid level' unless UserWarning.levels.keys.include?(level.to_s)

    errors.empty? ? Success({ reason: reason, level: level }) : Failure(errors)
  end

  def create_warning_record(user_id, moderator_id, data, expires_at)
    warning = UserWarning.create!(
      user_id: user_id,
      moderator_id: moderator_id,
      reason: data[:reason],
      level: data[:level],
      expires_at: expires_at
    )

    Success(warning)
  rescue ActiveRecord::RecordInvalid => e
    Failure(e.record.errors.full_messages)
  end

  def schedule_notification_job(warning)
    UserWarningNotificationJob.perform_async(warning.id)
    Success(warning)
  end

  def schedule_suspension_check_job(warning)
    UserWarningSuspensionCheckJob.perform_async(warning.user_id, warning.moderator_id)
    Success(warning)
  end

  def broadcast_warning_event(warning)
    # Event broadcasting for real-time updates
    EventBroadcaster.broadcast(
      event: :warning_issued,
      data: warning.as_json(include: [:user, :moderator]),
      channels: [:user_updates, :moderation_system],
      priority: :medium
    )

    Success(warning)
  end

  def validate_suspension_permissions(user_id, moderator_id)
    user = User.find_by(id: user_id)
    moderator = User.find_by(id: moderator_id)

    return Failure('User not found') unless user.present?
    return Failure('Moderator not found') unless moderator.present?
    return Failure('Moderator lacks permission') unless moderator.moderator? || moderator.admin?

    Success({ user: user, moderator: moderator })
  end

  def retrieve_active_warnings(user_id)
    warnings = UserWarning.active.where(user_id: user_id).to_a
    Success(warnings)
  end

  def evaluate_suspension_criteria(warnings)
    active_count = warnings.count
    should_suspend = active_count >= 3

    Success({ should_suspend: should_suspend, count: active_count })
  end

  def apply_suspension_if_needed(user_id, moderator_id, criteria)
    return Success({ suspended: false }) unless criteria[:should_suspend]

    user = User.find(user_id)
    user.update!(suspended_until: 7.days.from_now)

    # Schedule suspension notification
    UserWarningSuspensionNotificationJob.perform_async(user_id, moderator_id)

    Success({ suspended: true, until: 7.days.from_now })
  rescue ActiveRecord::RecordInvalid => e
    Failure(e.record.errors.full_messages)
  end

  def broadcast_suspension_event(result)
    EventBroadcaster.broadcast(
      event: :user_suspended,
      data: result,
      channels: [:user_management, :moderation_system],
      priority: :high
    )

    Success(result)
  end
end