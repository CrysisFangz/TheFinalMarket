class FraudAlert < ApplicationRecord
  include CircuitBreaker
  include Retryable

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

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Acknowledge alert
  def acknowledge!(by_user)
    with_retry do
      FraudAlertManagementService.acknowledge!(self, by_user)
    end
  end

  # Resolve alert
  def resolve!(by_user, notes = nil)
    with_retry do
      FraudAlertManagementService.resolve!(self, by_user, notes)
    end
  end

  # Check if alert is critical
  def critical?
    FraudAlertManagementService.critical?(self)
  end

  # Get alert badge color
  def badge_color
    FraudAlertManagementService.get_badge_color(self)
  end

  private

  def publish_created_event
    EventPublisher.publish('fraud_alert.created', {
      alert_id: id,
      fraud_check_id: fraud_check_id,
      user_id: user_id,
      alert_type: alert_type,
      severity: severity,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('fraud_alert.updated', {
      alert_id: id,
      fraud_check_id: fraud_check_id,
      user_id: user_id,
      alert_type: alert_type,
      severity: severity,
      acknowledged: acknowledged?,
      resolved: resolved?,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('fraud_alert.destroyed', {
      alert_id: id,
      fraud_check_id: fraud_check_id,
      user_id: user_id,
      alert_type: alert_type,
      severity: severity
    })
  end
end