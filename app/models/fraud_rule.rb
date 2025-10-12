class FraudRule < ApplicationRecord
  validates :name, presence: true
  validates :rule_type, presence: true
  validates :risk_weight, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  scope :active, -> { where(active: true) }
  scope :by_priority, -> { order(priority: :asc) }
  
  # Rule types
  enum rule_type: {
    velocity_check: 0,
    amount_threshold: 1,
    location_check: 2,
    device_check: 3,
    time_check: 4,
    pattern_check: 5,
    blacklist_check: 6,
    reputation_check: 7,
    custom: 9
  }
  
  # Evaluate rule against context
  def evaluate(context)
    return false unless active?
    
    case rule_type.to_sym
    when :velocity_check
      evaluate_velocity(context)
    when :amount_threshold
      evaluate_amount(context)
    when :location_check
      evaluate_location(context)
    when :device_check
      evaluate_device(context)
    when :time_check
      evaluate_time(context)
    when :pattern_check
      evaluate_pattern(context)
    when :blacklist_check
      evaluate_blacklist(context)
    when :reputation_check
      evaluate_reputation(context)
    else
      false
    end
  end
  
  private
  
  def evaluate_velocity(context)
    return false unless context[:user]
    
    threshold = conditions['threshold'] || 10
    timeframe = conditions['timeframe'] || 3600 # seconds
    
    count = FraudCheck.where(user: context[:user])
                      .where('created_at > ?', timeframe.seconds.ago)
                      .count
    
    count > threshold
  end
  
  def evaluate_amount(context)
    return false unless context[:amount]
    
    threshold = conditions['threshold'] || 1000_00 # cents
    context[:amount] > threshold
  end
  
  def evaluate_location(context)
    return false unless context[:ip_address]
    
    # Check if location is in blocked countries
    blocked_countries = conditions['blocked_countries'] || []
    
    begin
      result = Geocoder.search(context[:ip_address]).first
      return false unless result
      
      blocked_countries.include?(result.country_code)
    rescue
      false
    end
  end
  
  def evaluate_device(context)
    return false unless context[:device_fingerprint]
    
    fingerprint = DeviceFingerprint.find_by(fingerprint_hash: context[:device_fingerprint])
    return false unless fingerprint
    
    fingerprint.blocked? || fingerprint.suspicious?
  end
  
  def evaluate_time(context)
    hour = Time.current.hour
    
    blocked_hours = conditions['blocked_hours'] || []
    blocked_hours.include?(hour)
  end
  
  def evaluate_pattern(context)
    return false unless context[:user]
    
    BehavioralPattern.where(user: context[:user])
                     .anomalous
                     .recent
                     .exists?
  end
  
  def evaluate_blacklist(context)
    return false unless context[:ip_address]
    
    IpBlacklist.where(ip_address: context[:ip_address])
               .where('expires_at IS NULL OR expires_at > ?', Time.current)
               .exists?
  end
  
  def evaluate_reputation(context)
    return false unless context[:user]
    
    threshold = conditions['threshold'] || 30
    
    if context[:user].respond_to?(:reputation_score)
      context[:user].reputation_score < threshold
    else
      false
    end
  end
end

