class SecurityAudit < ApplicationRecord
  belongs_to :user, optional: true
  
  validates :event_type, presence: true
  validates :severity, presence: true
  
  scope :critical, -> { where(severity: :critical) }
  scope :high, -> { where(severity: :high) }
  scope :recent, -> { where('created_at > ?', 7.days.ago) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_event, ->(event) { where(event_type: event) }
  
  # Event types
  enum event_type: {
    login_success: 0,
    login_failure: 1,
    password_change: 2,
    email_change: 3,
    two_factor_enabled: 4,
    two_factor_disabled: 5,
    suspicious_activity: 6,
    account_locked: 7,
    account_unlocked: 8,
    permission_change: 9,
    data_export: 10,
    data_deletion: 11,
    api_access: 12,
    failed_authorization: 13,
    security_breach: 14
  }
  
  # Severity levels
  enum severity: {
    info: 0,
    low: 1,
    medium: 2,
    high: 3,
    critical: 4
  }
  
  # Log security event
  def self.log_event(event_type, user: nil, ip_address: nil, user_agent: nil, details: {})
    severity = calculate_severity(event_type, details)
    
    audit = create!(
      event_type: event_type,
      user: user,
      ip_address: ip_address,
      user_agent: user_agent,
      event_details: details,
      severity: severity,
      occurred_at: Time.current
    )
    
    # Alert if critical
    if audit.critical?
      SecurityAlertJob.perform_later(audit.id)
    end
    
    audit
  end
  
  # Get security score for user
  def self.security_score(user)
    events = where(user: user).where('created_at > ?', 30.days.ago)
    
    score = 100
    
    # Deduct points for security events
    score -= events.where(event_type: :login_failure).count * 2
    score -= events.where(event_type: :suspicious_activity).count * 10
    score -= events.where(event_type: :failed_authorization).count * 5
    score -= events.where(event_type: :security_breach).count * 50
    
    # Add points for good security practices
    score += 10 if user.two_factor_authentications.active.any?
    score += 5 if user.identity_verified?
    score += 5 if user.privacy_setting&.data_processing_consent
    
    [score, 0].max
  end
  
  # Get security recommendations
  def self.security_recommendations(user)
    recommendations = []
    
    unless user.two_factor_authentications.active.any?
      recommendations << {
        priority: 'high',
        title: 'Enable Two-Factor Authentication',
        description: 'Add an extra layer of security to your account',
        action: 'enable_2fa'
      }
    end
    
    unless user.identity_verified?
      recommendations << {
        priority: 'medium',
        title: 'Verify Your Identity',
        description: 'Increase trust and unlock premium features',
        action: 'verify_identity'
      }
    end
    
    if user.password_changed_at && user.password_changed_at < 90.days.ago
      recommendations << {
        priority: 'medium',
        title: 'Update Your Password',
        description: 'Your password hasn\'t been changed in 90 days',
        action: 'change_password'
      }
    end
    
    recent_failures = where(user: user, event_type: :login_failure)
                     .where('created_at > ?', 7.days.ago)
                     .count
    
    if recent_failures > 5
      recommendations << {
        priority: 'high',
        title: 'Review Recent Login Attempts',
        description: "#{recent_failures} failed login attempts in the past week",
        action: 'review_activity'
      }
    end
    
    recommendations
  end
  
  # Detect anomalies
  def self.detect_anomalies(user)
    anomalies = []
    
    # Check for unusual login locations
    recent_logins = where(user: user, event_type: :login_success)
                   .where('created_at > ?', 7.days.ago)
    
    locations = recent_logins.pluck(:ip_address).uniq
    if locations.count > 5
      anomalies << {
        type: 'multiple_locations',
        severity: 'medium',
        description: "Logins from #{locations.count} different locations"
      }
    end
    
    # Check for rapid login attempts
    login_attempts = where(user: user, event_type: [:login_success, :login_failure])
                    .where('created_at > ?', 1.hour.ago)
                    .count
    
    if login_attempts > 10
      anomalies << {
        type: 'rapid_login_attempts',
        severity: 'high',
        description: "#{login_attempts} login attempts in the past hour"
      }
    end
    
    # Check for suspicious activity
    suspicious = where(user: user, event_type: :suspicious_activity)
                .where('created_at > ?', 24.hours.ago)
                .count
    
    if suspicious > 0
      anomalies << {
        type: 'suspicious_activity',
        severity: 'critical',
        description: "#{suspicious} suspicious activities detected"
      }
    end
    
    anomalies
  end
  
  private
  
  def self.calculate_severity(event_type, details)
    case event_type.to_sym
    when :security_breach
      :critical
    when :suspicious_activity, :account_locked
      :high
    when :login_failure, :failed_authorization
      :medium
    when :password_change, :two_factor_enabled
      :low
    else
      :info
    end
  end
end

