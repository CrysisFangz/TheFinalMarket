class BehavioralPattern < ApplicationRecord
  belongs_to :user
  
  validates :pattern_type, presence: true
  
  scope :recent, -> { where('detected_at > ?', 30.days.ago) }
  scope :anomalous, -> { where(anomalous: true) }
  scope :for_user, ->(user) { where(user: user) }
  
  # Pattern types
  enum pattern_type: {
    login_pattern: 0,
    browsing_pattern: 1,
    purchase_pattern: 2,
    messaging_pattern: 3,
    listing_pattern: 4,
    search_pattern: 5,
    velocity_pattern: 6,
    time_pattern: 7,
    location_pattern: 8,
    device_pattern: 9
  }
  
  # Detect anomalies in user behavior
  def self.detect_anomalies_for(user)
    detector = BehavioralPatternDetector.new(user)
    detector.detect_all
  end
  
  # Check if pattern is anomalous
  def anomalous?
    anomalous == true
  end
  
  # Calculate anomaly score
  def anomaly_score
    return 0 unless anomalous?
    
    score = 0
    
    # Deviation from normal
    if pattern_data['deviation']
      score += (pattern_data['deviation'] * 30).to_i
    end
    
    # Frequency anomaly
    if pattern_data['frequency_anomaly']
      score += 25
    end
    
    # Time anomaly
    if pattern_data['time_anomaly']
      score += 20
    end
    
    # Location anomaly
    if pattern_data['location_anomaly']
      score += 25
    end
    
    [score, 100].min
  end
  
  # Get pattern description
  def description
    case pattern_type.to_sym
    when :login_pattern
      "Login behavior: #{pattern_data['description']}"
    when :browsing_pattern
      "Browsing behavior: #{pattern_data['description']}"
    when :purchase_pattern
      "Purchase behavior: #{pattern_data['description']}"
    when :messaging_pattern
      "Messaging behavior: #{pattern_data['description']}"
    when :listing_pattern
      "Listing behavior: #{pattern_data['description']}"
    when :velocity_pattern
      "Activity velocity: #{pattern_data['description']}"
    else
      "Pattern detected: #{pattern_data['description']}"
    end
  end
end

