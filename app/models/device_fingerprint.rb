class DeviceFingerprint < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :user, optional: true
  has_many :fraud_checks, as: :checkable, dependent: :destroy

  validates :fingerprint_hash, presence: true, uniqueness: true

  scope :recent, -> { where('last_seen_at > ?', 30.days.ago) }
  scope :suspicious, -> { where(suspicious: true) }
  scope :blocked, -> { where(blocked: true) }
  scope :for_user, ->(user) { where(user: user) }

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Update last seen
  def touch_last_seen!
    DeviceManagementService.touch_last_seen!(self)
  end

  # Check if device is new
  def new_device?
    created_at > 7.days.ago
  end

  # Check if device is used by multiple users
  def shared_device?
    Rails.cache.fetch("device:#{id}:shared", expires_in: 1.hour) do
      return false unless user_id

      DeviceFingerprint.where(fingerprint_hash: fingerprint_hash)
                       .where.not(user_id: user_id)
                       .exists?
    end
  end

  # Get all users who used this device
  def associated_users
    Rails.cache.fetch("device:#{id}:associated_users", expires_in: 1.hour) do
      User.where(id: DeviceFingerprint.where(fingerprint_hash: fingerprint_hash).pluck(:user_id))
    end
  end

  # Calculate risk score for this device
  def calculate_risk_score
    Rails.cache.fetch("device:#{id}:risk_score", expires_in: 30.minutes) do
      DeviceRiskAssessmentService.calculate_risk_score(self)
    end
  end

  # Check for inconsistent location
  def inconsistent_location?
    GeolocationService.inconsistent_location?(self)
  end

  # Mark as suspicious
  def mark_suspicious!(reason)
    DeviceManagementService.mark_suspicious!(self, reason)
  end

  # Block device
  def block!(reason)
    DeviceManagementService.block!(self, reason)
  end

  # Unblock device
  def unblock!
    DeviceManagementService.unblock!(self)
  end

  # Get risk score (alias for calculate_risk_score)
  def risk_score
    calculate_risk_score
  end

  private

  def publish_created_event
    EventPublisher.publish('device_fingerprint.created', {
      device_id: id,
      fingerprint_hash: fingerprint_hash,
      user_id: user_id,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('device_fingerprint.updated', {
      device_id: id,
      fingerprint_hash: fingerprint_hash,
      user_id: user_id,
      suspicious: suspicious?,
      blocked: blocked?,
      risk_score: risk_score,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('device_fingerprint.destroyed', {
      device_id: id,
      fingerprint_hash: fingerprint_hash,
      user_id: user_id
    })
  end
end