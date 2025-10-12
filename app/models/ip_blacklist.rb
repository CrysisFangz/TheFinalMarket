class IpBlacklist < ApplicationRecord
  validates :ip_address, presence: true, uniqueness: true
  
  scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :permanent, -> { where(permanent: true) }
  scope :temporary, -> { where(permanent: false) }
  scope :by_severity, -> { order(severity: :desc) }
  
  # Check if IP is blacklisted
  def self.blacklisted?(ip)
    active.exists?(ip_address: ip)
  end
  
  # Add IP to blacklist
  def self.add(ip, reason, severity: 1, duration: nil, added_by: nil)
    expires_at = duration ? duration.from_now : nil
    permanent = duration.nil?
    
    create!(
      ip_address: ip,
      reason: reason,
      severity: severity,
      expires_at: expires_at,
      permanent: permanent,
      added_by: added_by
    )
  end
  
  # Remove IP from blacklist
  def self.remove(ip)
    find_by(ip_address: ip)&.destroy
  end
  
  # Check if blacklist entry is expired
  def expired?
    return false if permanent?
    return false unless expires_at
    
    expires_at < Time.current
  end
  
  # Check if blacklist entry is active
  def active?
    permanent? || !expired?
  end
end

