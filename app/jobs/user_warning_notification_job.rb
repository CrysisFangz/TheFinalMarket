# UserWarningNotificationJob - Asynchronous Warning Notification Processing
#
# This job handles user notifications for issued warnings with comprehensive
# error handling, retries, and performance optimization following the Prime Mandate.

class UserWarningNotificationJob < ApplicationJob
  queue_as :notifications

  sidekiq_options(
    retry: 3,
    backtrace: true,
    lock: :until_executed,
    lock_ttl: 60
  )

  def perform(warning_id)
    warning = UserWarning.find_by(id: warning_id)
    return unless warning.present?

    execute_with_error_handling do
      validate_notification_requirements(warning)
      send_notification(warning)
      record_notification_success(warning)
    end
  rescue StandardError => e
    handle_notification_error(e, warning)
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

  def validate_notification_requirements(warning)
    raise JobValidationError, "Warning not found: #{warning_id}" unless warning.present?
    raise JobValidationError, "User not found" unless warning.user.present?
    raise JobValidationError, "Moderator not found" unless warning.moderator.present?
  end

  def send_notification(warning)
    warning.user.notify(
      actor: warning.moderator,
      action: 'issued_warning',
      notifiable: warning
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to send warning notification: #{e.message}")
    raise NotificationError, "Notification failed for warning #{warning.id}"
  end

  def record_notification_success(warning)
    # Record successful notification for audit
    NotificationAudit.create!(
      user_id: warning.user_id,
      moderator_id: warning.moderator_id,
      action: 'warning_notification_sent',
      notifiable_type: 'UserWarning',
      notifiable_id: warning.id,
      sent_at: Time.current
    )
  end

  def handle_notification_error(error, warning)
    # Log detailed error information
    ErrorLogger.log(
      error_class: error.class.name,
      error_message: error.message,
      error_backtrace: error.backtrace,
      warning_id: warning&.id,
      user_id: warning&.user_id,
      severity: :high
    )

    # Trigger alert for critical failures
    trigger_critical_alert(error, warning) if critical_error?(error)
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

  def trigger_critical_alert(error, warning)
    CriticalAlertService.trigger(
      alert_type: :notification_failure,
      error: error,
      job_metadata: {
        job_class: self.class.name,
        warning_id: warning.id,
        user_id: warning.user_id
      },
      severity: :high
    )
  end

  # Custom error classes
  class JobValidationError < StandardError; end
  class NotificationError < StandardError; end
end