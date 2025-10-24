# UserWarningSuspensionCheckJob - Asynchronous Suspension Check Processing
#
# This job handles automatic suspension checks for users with multiple warnings,
# ensuring scalable and resilient processing following the Prime Mandate.

class UserWarningSuspensionCheckJob < ApplicationJob
  queue_as :moderation

  sidekiq_options(
    retry: 3,
    backtrace: true,
    lock: :until_executed,
    lock_ttl: 120
  )

  def perform(user_id, moderator_id)
    execute_with_error_handling do
      validate_suspension_requirements(user_id, moderator_id)
      check_and_apply_suspension(user_id, moderator_id)
      record_suspension_check_success(user_id)
    end
  rescue StandardError => e
    handle_suspension_error(e, user_id, moderator_id)
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

  def validate_suspension_requirements(user_id, moderator_id)
    user = User.find_by(id: user_id)
    moderator = User.find_by(id: moderator_id)

    raise JobValidationError, "User not found: #{user_id}" unless user.present?
    raise JobValidationError, "Moderator not found: #{moderator_id}" unless moderator.present?
    raise JobValidationError, "Moderator lacks permission" unless moderator.moderator? || moderator.admin?
  end

  def check_and_apply_suspension(user_id, moderator_id)
    service = WarningService.new
    result = service.check_and_apply_suspension(user_id, moderator_id)

    unless result.success?
      raise SuspensionError, "Suspension check failed: #{result.failure}"
    end
  end

  def record_suspension_check_success(user_id)
    # Record successful suspension check for audit
    SuspensionAudit.create!(
      user_id: user_id,
      action: 'suspension_check_completed',
      completed_at: Time.current,
      result: 'success'
    )
  end

  def handle_suspension_error(error, user_id, moderator_id)
    # Log detailed error information
    ErrorLogger.log(
      error_class: error.class.name,
      error_message: error.message,
      error_backtrace: error.backtrace,
      user_id: user_id,
      moderator_id: moderator_id,
      severity: :critical
    )

    # Trigger alert for critical failures
    trigger_critical_alert(error, user_id, moderator_id)
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

  def trigger_critical_alert(error, user_id, moderator_id)
    CriticalAlertService.trigger(
      alert_type: :suspension_failure,
      error: error,
      job_metadata: {
        job_class: self.class.name,
        user_id: user_id,
        moderator_id: moderator_id
      },
      severity: :critical
    )
  end

  # Custom error classes
  class JobValidationError < StandardError; end
  class SuspensionError < StandardError; end
end