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
  
  def self.log_event(event_type, user: nil, ip_address: nil, user_agent: nil, details: {})
    SecurityEventLogger.log_event(event_type, user: user, ip_address: ip_address, user_agent: user_agent, details: details)
  end
  
  def self.security_score(user)
    SecurityScorer.score_for(user)
  end
  
  def self.security_recommendations(user)
    SecurityRecommender.recommendations_for(user)
  end
  
  def self.detect_anomalies(user)
    # Trigger async detection
    SecurityAnomalyDetectionJob.perform_later(user.id)
    # Return cached or immediate result if needed
    SecurityAnomalyDetector.detect_for(user)
  end
  
  def to_presenter
    SecurityAuditPresenter.new(self)
  end

  private
end

