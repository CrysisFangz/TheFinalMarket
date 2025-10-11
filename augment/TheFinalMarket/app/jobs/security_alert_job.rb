class SecurityAlertJob < ApplicationJob
  queue_as :high_priority
  
  def perform(audit_id)
    audit = SecurityAudit.find(audit_id)
    
    Rails.logger.warn "SECURITY ALERT: #{audit.event_type} - Severity: #{audit.severity}"
    
    # Send alert to user
    if audit.user
      SecurityMailer.security_alert(audit.user, audit).deliver_now
    end
    
    # Send alert to security team
    SecurityMailer.admin_alert(audit).deliver_now
    
    # Log to external monitoring (Sentry, DataDog, etc.)
    if defined?(Sentry)
      Sentry.capture_message(
        "Security Alert: #{audit.event_type}",
        level: audit.severity,
        extra: {
          user_id: audit.user_id,
          ip_address: audit.ip_address,
          details: audit.event_details
        }
      )
    end
    
    # Mark as alerted
    audit.update!(alerted: true)
  end
end

