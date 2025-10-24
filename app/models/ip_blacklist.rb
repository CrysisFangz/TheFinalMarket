class IpBlacklist < ApplicationRecord
  include CircuitBreaker
  include Retryable

  validates :ip_address, presence: true, uniqueness: true

  # Enhanced scopes with caching
  scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :permanent, -> { where(permanent: true) }
  scope :temporary, -> { where(permanent: false) }
  scope :by_severity, -> { order(severity: :desc) }

  # Caching
  after_create :clear_blacklist_cache
  after_update :clear_blacklist_cache
  after_destroy :clear_blacklist_cache

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event
  
  # Check if IP is blacklisted
  def self.blacklisted?(ip)
    IpBlacklistManagementService.check_blacklisted(ip)
  end

  # Add IP to blacklist
  def self.add(ip, reason, severity: 1, duration: nil, added_by: nil)
    IpBlacklistManagementService.add_to_blacklist(ip, reason, severity: severity, duration: duration, added_by: added_by)
  end

  # Remove IP from blacklist
  def self.remove(ip)
    IpBlacklistManagementService.remove_from_blacklist(ip)
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

  def self.cached_find(id)
    Rails.cache.fetch("ip_blacklist:#{id}", expires_in: 30.minutes) do
      find_by(id: id)
    end
  end

  def self.cached_find_by_ip(ip)
    Rails.cache.fetch("ip_blacklist:ip:#{ip}", expires_in: 15.minutes) do
      active.find_by(ip_address: ip)
    end
  end

  def self.cached_active_entries
    Rails.cache.fetch("ip_blacklist:active_entries", expires_in: 10.minutes) do
      active.includes(:added_by_user).to_a
    end
  end

  def self.get_blacklist_stats
    IpBlacklistManagementService.get_blacklist_stats
  end

  def self.process_expired_entries
    IpBlacklistManagementService.process_expired_entries
  end

  def self.validate_ip(ip)
    IpValidationService.validate_ip_address(ip)
  end

  def self.get_ip_reputation(ip)
    IpValidationService.check_ip_reputation(ip)
  end

  def self.get_ip_geolocation(ip)
    IpValidationService.get_ip_geolocation(ip)
  end

  def self.get_threat_intelligence(ip)
    IpValidationService.check_threat_intelligence(ip)
  end

  def presenter
    @presenter ||= IpBlacklistPresenter.new(self)
  end

  private

  def clear_blacklist_cache
    IpBlacklistManagementService.clear_management_cache
    IpValidationService.clear_validation_cache(ip_address)

    # Clear related caches
    Rails.cache.delete("ip_blacklist:#{id}")
    Rails.cache.delete("ip_blacklist:ip:#{ip_address}")
    Rails.cache.delete("ip_blacklist:active_entries")
  end

  def publish_created_event
    EventPublisher.publish('ip_blacklist.created', {
      blacklist_id: id,
      ip_address: ip_address,
      reason: reason,
      severity: severity,
      permanent: permanent,
      expires_at: expires_at,
      added_by: added_by,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('ip_blacklist.updated', {
      blacklist_id: id,
      ip_address: ip_address,
      reason: reason,
      severity: severity,
      permanent: permanent,
      expires_at: expires_at,
      added_by: added_by,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('ip_blacklist.destroyed', {
      blacklist_id: id,
      ip_address: ip_address,
      reason: reason,
      severity: severity,
      permanent: permanent,
      expires_at: expires_at,
      added_by: added_by
    })
  end
end

