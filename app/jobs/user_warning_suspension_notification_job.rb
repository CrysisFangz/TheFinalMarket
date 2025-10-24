# UserWarningSuspensionNotificationJob - Asynchronous Suspension Notification Processing
#
# This job handles notifications for user suspensions with comprehensive
# error handling and resilience following the Prime Mandate.

class UserWarningSuspensionNotificationJob < ApplicationJob
  queue_as :notifications

  sidekiq_options(
    retry: 3,
    backtrace: true,
    lock: :until_executed,
    lock_ttl: 60
  )

  def perform(user_id, moderator_id)
    execute_with_error_handling do
      validate_notification_requirements(user_id, moderator_id)
      send_suspension_notification(user_id, moderator_id)
      record_notification_success(user_id, moderator_id)
    end
  rescue StandardError => e
    handle_notification_error(e, user_id, moderator_id)
    raise e # Re-raise for Sidekiq retry
  end

  private

  def execute_with_error_handling
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    begin
      yield
    ensure
      execution_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      record_job_metrics(execution_time)
    end
  end

  def validate_notification_requirements(user_id, moderator_id)
    user = User.find_by(id: user_id)
    moderator = User.find_by(id: moderator_id)

    raise JobValidationError, "User not found: #{user_id}" unless user.present?
    raise JobValidationError, "Moderator not found: #{moderator_id}" unless moderator.present?
    raise JobValidationError, "User not suspended" unless user.suspended_until.present?
  end

  def send_suspension_notification(user_id, moderator_id)
    user = User.find(user_id)
    moderator = User.find(moderator_id)

    user.notify(
      actor: moderator,
      action: 'account_suspended',
      notifiable: user
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to send suspension notification: #{e.message}")
    raise NotificationError, "Suspension notification failed for user #{user_id}"
  end

  def record_notification_success(user_id, moderator_id)
    # Record successful notification for audit
    NotificationAudit.create!(
      user_id: user_id,
      moderator_id: moderator_id,
      action: 'suspension_notification_sent',
      notifiable_type: 'User',
      notifiable_id: user_id,
      sent_at: Time.current
    )
  end

  def handle_notification_error(error, user_id, moderator_id)
    # Log detailed error information
    ErrorLogger.log(
      error_class: error.class.name,
      error_message: error.message,
      error_backtrace: error.backtrace,
      user_id: user_id,
      moderator_id: moderator_id,
      severity: :high
    )

    # Trigger alert for critical failures
    trigger_critical_alert(error, user_id, moderator_id) if critical_error?(error)
  end

  def record_job_metrics(execution_time)
    JobMetricsRecorder.record(
      job_class: self.class.name,
      execution_time_ms: (execution_time * 1000).round(2),
      success: true,
      memory_usage: 0, # Placeholder
      cpu_usage: 0.0   # Placeholder
    )
  end

  def critical_error?(error)
    error.is_a?(NotificationError) || retry_count >= 2
  end

  def trigger_critical_alert(error, user_id, moderator_id)
    CriticalAlertService.trigger(
      alert_type: :suspension_notification_failure,
      error: error,
      job_metadata: {
        job_class: self.class.name,
        user_id: user_id,
        moderator_id: moderator_id
      },
      severity: :high
    )
  end

  # Custom error classes
  class JobValidationError < StandardError; end
  class NotificationError < StandardError; end
end