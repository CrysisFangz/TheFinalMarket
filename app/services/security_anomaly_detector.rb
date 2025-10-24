class SecurityAnomalyDetector
  def self.detect_for(user)
    cache_key = "security_anomalies_user_#{user.id}_#{SecurityAudit.where(user: user).maximum(:updated_at).to_i}"

    Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      anomalies = []

      # Check for unusual login locations
      recent_logins = SecurityAudit.where(user: user, event_type: :login_success)
                                  .where('created_at > ?', 7.days.ago)
                                  .pluck(:ip_address)
      unique_locations = recent_logins.uniq
      if unique_locations.count > 5
        anomalies << build_anomaly('multiple_locations', 'medium', "Logins from #{unique_locations.count} different locations")
      end

      # Check for rapid login attempts
      login_attempts = SecurityAudit.where(user: user, event_type: [:login_success, :login_failure])
                                    .where('created_at > ?', 1.hour.ago)
                                    .count
      if login_attempts > 10
        anomalies << build_anomaly('rapid_login_attempts', 'high', "#{login_attempts} login attempts in the past hour")
      end

      # Check for suspicious activity
      suspicious_count = SecurityAudit.where(user: user, event_type: :suspicious_activity)
                                     .where('created_at > ?', 24.hours.ago)
                                     .count
      if suspicious_count > 0
        anomalies << build_anomaly('suspicious_activity', 'critical', "#{suspicious_count} suspicious activities detected")
      end

      anomalies
    end
  rescue => e
    Rails.logger.error("Error detecting anomalies: #{e.message}")
    []
  end

  private

  def self.build_anomaly(type, severity, description)
    {
      type: type,
      severity: severity,
      description: description
    }
  end
end