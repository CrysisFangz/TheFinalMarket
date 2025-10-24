class SecurityEventLogger
  include CircuitBreaker

  def self.log_event(event_type, user: nil, ip_address: nil, user_agent: nil, details: {})
    with_circuit_breaker(name: 'security_event_logging') do
      severity = SecuritySeverityCalculator.calculate(event_type, details)

      audit = SecurityAudit.create!(
        event_type: event_type,
        user: user,
        ip_address: ip_address,
        user_agent: user_agent,
        event_details: details,
        severity: severity,
        occurred_at: Time.current
      )

      # Alert if critical - async
      SecurityAlertJob.perform_later(audit.id) if audit.critical?

      audit
    end
  rescue ActiveRecord::RecordInvalid => e
    # Log error and handle gracefully
    Rails.logger.error("Failed to log security event: #{e.message}")
    nil
  end
end