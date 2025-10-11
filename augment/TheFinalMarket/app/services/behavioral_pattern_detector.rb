class BehavioralPatternDetector
  attr_reader :user
  
  def initialize(user)
    @user = user
  end
  
  # Detect all patterns
  def detect_all
    patterns = []
    
    patterns << detect_login_pattern
    patterns << detect_browsing_pattern
    patterns << detect_purchase_pattern
    patterns << detect_velocity_pattern
    patterns << detect_time_pattern
    patterns << detect_location_pattern
    
    patterns.compact
  end
  
  private
  
  # Detect login pattern anomalies
  def detect_login_pattern
    return nil unless user.respond_to?(:sign_in_count)
    
    # Get recent logins
    recent_logins = FraudCheck.where(user: user, check_type: :login_attempt)
                              .where('created_at > ?', 30.days.ago)
                              .order(created_at: :asc)
    
    return nil if recent_logins.count < 5
    
    # Calculate average time between logins
    time_diffs = []
    recent_logins.each_cons(2) do |login1, login2|
      time_diffs << (login2.created_at - login1.created_at).to_i
    end
    
    avg_diff = time_diffs.sum / time_diffs.size.to_f
    std_dev = calculate_std_dev(time_diffs, avg_diff)
    
    # Check for anomalies
    anomalous = false
    description = "Normal login pattern"
    
    # Check last login
    if recent_logins.count >= 2
      last_diff = (recent_logins.last.created_at - recent_logins[-2].created_at).to_i
      
      if (last_diff - avg_diff).abs > (std_dev * 3)
        anomalous = true
        description = "Unusual login timing (#{last_diff}s vs avg #{avg_diff.to_i}s)"
      end
    end
    
    # Check for rapid logins
    rapid_logins = recent_logins.where('created_at > ?', 1.hour.ago).count
    if rapid_logins > 10
      anomalous = true
      description = "Rapid login attempts (#{rapid_logins} in 1 hour)"
    end
    
    BehavioralPattern.create!(
      user: user,
      pattern_type: :login_pattern,
      anomalous: anomalous,
      pattern_data: {
        description: description,
        avg_time_between: avg_diff.to_i,
        std_dev: std_dev.to_i,
        recent_count: recent_logins.count
      },
      detected_at: Time.current
    )
  end
  
  # Detect browsing pattern anomalies
  def detect_browsing_pattern
    # Get page views (would need to track these)
    # For now, return nil
    nil
  end
  
  # Detect purchase pattern anomalies
  def detect_purchase_pattern
    orders = user.orders.where('created_at > ?', 90.days.ago).order(created_at: :asc)
    
    return nil if orders.count < 3
    
    # Calculate average order value
    avg_value = orders.average(:total_cents).to_f
    std_dev_value = calculate_std_dev(orders.pluck(:total_cents), avg_value)
    
    # Check last order
    last_order = orders.last
    anomalous = false
    description = "Normal purchase pattern"
    
    if (last_order.total_cents - avg_value).abs > (std_dev_value * 3)
      anomalous = true
      description = "Unusual order value ($#{last_order.total_cents/100.0} vs avg $#{(avg_value/100.0).round(2)})"
    end
    
    # Check purchase frequency
    time_diffs = []
    orders.each_cons(2) do |order1, order2|
      time_diffs << (order2.created_at - order1.created_at).to_i / 86400.0 # days
    end
    
    if time_diffs.any?
      avg_days = time_diffs.sum / time_diffs.size
      last_days = time_diffs.last
      
      if last_days < avg_days / 3 && last_days < 1
        anomalous = true
        description = "Unusually rapid purchases (#{last_days.round(1)} days vs avg #{avg_days.round(1)} days)"
      end
    end
    
    BehavioralPattern.create!(
      user: user,
      pattern_type: :purchase_pattern,
      anomalous: anomalous,
      pattern_data: {
        description: description,
        avg_order_value: avg_value.to_i,
        std_dev: std_dev_value.to_i,
        order_count: orders.count
      },
      detected_at: Time.current
    )
  end
  
  # Detect velocity anomalies
  def detect_velocity_pattern
    # Count actions in different time windows
    last_hour = FraudCheck.where(user: user).where('created_at > ?', 1.hour.ago).count
    last_day = FraudCheck.where(user: user).where('created_at > ?', 1.day.ago).count
    last_week = FraudCheck.where(user: user).where('created_at > ?', 7.days.ago).count
    
    return nil if last_week < 10
    
    # Calculate average rates
    avg_per_hour = last_week / (7.0 * 24.0)
    avg_per_day = last_week / 7.0
    
    anomalous = false
    description = "Normal activity velocity"
    
    # Check for velocity spikes
    if last_hour > avg_per_hour * 10 && last_hour > 20
      anomalous = true
      description = "Extreme activity spike (#{last_hour} actions/hour vs avg #{avg_per_hour.round(1)})"
    elsif last_day > avg_per_day * 5 && last_day > 50
      anomalous = true
      description = "High activity spike (#{last_day} actions/day vs avg #{avg_per_day.round(1)})"
    end
    
    BehavioralPattern.create!(
      user: user,
      pattern_type: :velocity_pattern,
      anomalous: anomalous,
      pattern_data: {
        description: description,
        last_hour: last_hour,
        last_day: last_day,
        avg_per_hour: avg_per_hour.round(2),
        avg_per_day: avg_per_day.round(2)
      },
      detected_at: Time.current
    )
  end
  
  # Detect time pattern anomalies
  def detect_time_pattern
    recent_checks = FraudCheck.where(user: user)
                              .where('created_at > ?', 30.days.ago)
                              .pluck(:created_at)
    
    return nil if recent_checks.count < 20
    
    # Get hours of activity
    hours = recent_checks.map { |t| t.hour }
    hour_counts = hours.group_by(&:itself).transform_values(&:count)
    
    # Find most common hours
    common_hours = hour_counts.sort_by { |_, count| -count }.first(3).map(&:first)
    
    # Check current hour
    current_hour = Time.current.hour
    anomalous = false
    description = "Normal activity time"
    
    # Unusual hours (2 AM - 5 AM)
    if current_hour >= 2 && current_hour <= 5
      if !common_hours.include?(current_hour)
        anomalous = true
        description = "Activity at unusual hour (#{current_hour}:00)"
      end
    end
    
    BehavioralPattern.create!(
      user: user,
      pattern_type: :time_pattern,
      anomalous: anomalous,
      pattern_data: {
        description: description,
        current_hour: current_hour,
        common_hours: common_hours,
        hour_distribution: hour_counts
      },
      detected_at: Time.current
    )
  end
  
  # Detect location pattern anomalies
  def detect_location_pattern
    recent_checks = FraudCheck.where(user: user)
                              .where('created_at > ?', 30.days.ago)
                              .where.not(ip_address: nil)
                              .pluck(:ip_address, :created_at)
    
    return nil if recent_checks.count < 5
    
    # Get locations from IPs
    locations = recent_checks.map do |ip, time|
      begin
        result = Geocoder.search(ip).first
        { country: result&.country_code, city: result&.city, time: time }
      rescue
        nil
      end
    end.compact
    
    return nil if locations.empty?
    
    # Find most common location
    common_country = locations.map { |l| l[:country] }.group_by(&:itself).max_by { |_, v| v.size }&.first
    
    # Check for location jumps
    anomalous = false
    description = "Normal location pattern"
    
    locations.each_cons(2) do |loc1, loc2|
      if loc1[:country] != loc2[:country]
        time_diff = (loc2[:time] - loc1[:time]) / 3600.0 # hours
        
        if time_diff < 2
          anomalous = true
          description = "Impossible travel (#{loc1[:country]} to #{loc2[:country]} in #{time_diff.round(1)} hours)"
          break
        end
      end
    end
    
    BehavioralPattern.create!(
      user: user,
      pattern_type: :location_pattern,
      anomalous: anomalous,
      pattern_data: {
        description: description,
        common_country: common_country,
        location_count: locations.count,
        unique_countries: locations.map { |l| l[:country] }.uniq.count
      },
      detected_at: Time.current
    )
  end
  
  # Helper: Calculate standard deviation
  def calculate_std_dev(values, mean)
    return 0 if values.empty?
    
    variance = values.map { |v| (v - mean) ** 2 }.sum / values.size.to_f
    Math.sqrt(variance)
  end
end

