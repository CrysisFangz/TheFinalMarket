class FraudAlert < ApplicationRecord
  belongs_to :fraud_check
  belongs_to :user, optional: true
  belongs_to :acknowledged_by, class_name: 'User', optional: true
  belongs_to :resolved_by, class_name: 'User', optional: true
  
  validates :alert_type, presence: true
  validates :severity, presence: true
  
  scope :recent, -> { where('created_at > ?', 7.days.ago) }
  scope :unacknowledged, -> { where(acknowledged: false) }
  scope :unresolved, -> { where(resolved: false) }
  scope :critical, -> { where(severity: 3) }
  scope :high, -> { where(severity: 2) }
  
  # Alert types
  enum alert_type: {
    high_risk_transaction: 0,
    suspicious_login: 1,
    account_takeover: 2,
    payment_fraud: 3,
    identity_theft: 4,
    bot_activity: 5,
    velocity_abuse: 6,
    chargeback_risk: 7,
    multiple_accounts: 8,
    vpn_detected: 9
  }
  
  # Severity levels
  enum severity: {
    low: 1,
    medium: 2,
    high: 3
  }
  
  # Acknowledge alert
  def acknowledge!(by_user)
    update!(
      acknowledged: true,
      acknowledged_at: Time.current,
      acknowledged_by: by_user
    )
  end
  
  # Resolve alert
  def resolve!(by_user, notes = nil)
    update!(
      resolved: true,
      resolved_at: Time.current,
      resolved_by: by_user,
      resolution_notes: notes
    )
  end
  
  # Check if alert is critical
  def critical?
    severity == 'high'
  end
  
  # Get alert badge color
  def badge_color
    case severity.to_sym
    when :high
      'red'
    when :medium
      'orange'
    when :low
      'yellow'
    end
  end
end

