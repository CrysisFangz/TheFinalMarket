class DeviceFingerprint < ApplicationRecord
  belongs_to :user, optional: true
  has_many :fraud_checks, as: :checkable, dependent: :destroy
  
  validates :fingerprint_hash, presence: true, uniqueness: true
  
  scope :recent, -> { where('last_seen_at > ?', 30.days.ago) }
  scope :suspicious, -> { where(suspicious: true) }
  scope :blocked, -> { where(blocked: true) }
  scope :for_user, ->(user) { where(user: user) }
  
  # Update last seen
  def touch_last_seen!
    update!(
      last_seen_at: Time.current,
      access_count: access_count + 1
    )
  end
  
  # Check if device is new
  def new_device?
    created_at > 7.days.ago
  end
  
  # Check if device is used by multiple users
  def shared_device?
    return false unless user_id
    
    DeviceFingerprint.where(fingerprint_hash: fingerprint_hash)
                     .where.not(user_id: user_id)
                     .exists?
  end
  
  # Get all users who used this device
  def associated_users
    User.where(id: DeviceFingerprint.where(fingerprint_hash: fingerprint_hash).pluck(:user_id))
  end
  
  # Calculate risk score for this device
  def calculate_risk_score
    score = 0
    
    # New device
    score += 10 if new_device?
    
    # Shared device
    score += 20 if shared_device?
    
    # Suspicious flag
    score += 30 if suspicious?
    
    # High access count in short time
    if created_at > 1.day.ago && access_count > 50
      score += 15
    end
    
    # VPN/Proxy detected
    score += 25 if device_info.dig('vpn_detected')
    
    # Inconsistent location
    score += 20 if inconsistent_location?
    
    [score, 100].min
  end
  
  # Check for inconsistent location
  def inconsistent_location?
    return false unless last_ip_address && device_info['country']
    
    # Get location from IP
    current_location = Geocoder.search(last_ip_address).first
    return false unless current_location
    
    # Compare with stored location
    stored_country = device_info['country']
    current_location.country_code != stored_country
  end
  
  # Mark as suspicious
  def mark_suspicious!(reason)
    update!(
      suspicious: true,
      suspicious_reason: reason,
      suspicious_at: Time.current
    )
  end
  
  # Block device
  def block!(reason)
    update!(
      blocked: true,
      blocked_reason: reason,
      blocked_at: Time.current
    )
  end
  
  # Unblock device
  def unblock!
    update!(
      blocked: false,
      blocked_reason: nil,
      blocked_at: nil
    )
  end
end

