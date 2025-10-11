class FraudDetectionService
  attr_reader :user, :checkable, :check_type, :context
  
  def initialize(user, checkable, check_type, context = {})
    @user = user
    @checkable = checkable
    @check_type = check_type
    @context = context
  end
  
  # Perform fraud check
  def check
    risk_score = calculate_risk_score
    
    fraud_check = FraudCheck.create!(
      user: user,
      checkable: checkable,
      check_type: check_type,
      risk_score: risk_score,
      factors: { factors: @risk_factors },
      ip_address: context[:ip_address],
      user_agent: context[:user_agent],
      flagged: risk_score >= 70
    )
    
    # Take action if high risk
    if fraud_check.high_risk?
      take_action(fraud_check)
    end
    
    fraud_check
  end
  
  # Calculate overall risk score
  def calculate_risk_score
    @risk_factors = []
    score = 0
    
    # User-based checks
    score += check_user_age
    score += check_user_reputation
    score += check_user_verification
    score += check_user_history
    
    # Device-based checks
    score += check_device_fingerprint
    score += check_ip_address
    score += check_vpn_proxy
    
    # Behavioral checks
    score += check_velocity
    score += check_patterns
    score += check_anomalies
    
    # Transaction-specific checks
    score += check_transaction_amount if checkable.is_a?(Order)
    score += check_payment_method if checkable.is_a?(Order)
    
    # Content-based checks
    score += check_content_spam if checkable.respond_to?(:content)
    
    [score, 100].min
  end
  
  private
  
  # Check user account age
  def check_user_age
    return 0 unless user
    
    age_days = (Time.current - user.created_at) / 1.day
    
    if age_days < 1
      add_risk_factor("Very new account (< 1 day)", 20)
      20
    elsif age_days < 7
      add_risk_factor("New account (< 7 days)", 10)
      10
    elsif age_days < 30
      add_risk_factor("Recent account (< 30 days)", 5)
      5
    else
      0
    end
  end
  
  # Check user reputation
  def check_user_reputation
    return 0 unless user
    
    if user.respond_to?(:reputation_score)
      if user.reputation_score < 20
        add_risk_factor("Low reputation score", 15)
        15
      elsif user.reputation_score < 50
        add_risk_factor("Below average reputation", 5)
        5
      else
        0
      end
    else
      0
    end
  end
  
  # Check user verification
  def check_user_verification
    return 0 unless user
    
    score = 0
    
    unless user.email_verified?
      add_risk_factor("Email not verified", 10)
      score += 10
    end
    
    if user.respond_to?(:phone_verified?) && !user.phone_verified?
      add_risk_factor("Phone not verified", 5)
      score += 5
    end
    
    score
  end
  
  # Check user history
  def check_user_history
    return 0 unless user
    
    # Check for previous fraud flags
    previous_flags = FraudCheck.where(user: user).flagged.count
    
    if previous_flags > 5
      add_risk_factor("Multiple previous fraud flags (#{previous_flags})", 25)
      25
    elsif previous_flags > 2
      add_risk_factor("Some previous fraud flags (#{previous_flags})", 15)
      15
    elsif previous_flags > 0
      add_risk_factor("Previous fraud flag", 5)
      5
    else
      0
    end
  end
  
  # Check device fingerprint
  def check_device_fingerprint
    return 0 unless context[:device_fingerprint]
    
    fingerprint = DeviceFingerprint.find_by(fingerprint_hash: context[:device_fingerprint])
    return 0 unless fingerprint
    
    score = 0
    
    if fingerprint.blocked?
      add_risk_factor("Blocked device", 50)
      score += 50
    elsif fingerprint.suspicious?
      add_risk_factor("Suspicious device", 25)
      score += 25
    end
    
    if fingerprint.shared_device?
      add_risk_factor("Shared device", 10)
      score += 10
    end
    
    score
  end
  
  # Check IP address
  def check_ip_address
    return 0 unless context[:ip_address]
    
    ip = context[:ip_address]
    
    # Check if IP is blacklisted
    if ip_blacklisted?(ip)
      add_risk_factor("Blacklisted IP address", 40)
      return 40
    end
    
    # Check for multiple accounts from same IP
    if user
      same_ip_users = User.where.not(id: user.id)
                         .joins(:fraud_checks)
                         .where(fraud_checks: { ip_address: ip })
                         .distinct
                         .count
      
      if same_ip_users > 5
        add_risk_factor("Many accounts from same IP (#{same_ip_users})", 20)
        return 20
      elsif same_ip_users > 2
        add_risk_factor("Multiple accounts from same IP", 10)
        return 10
      end
    end
    
    0
  end
  
  # Check for VPN/Proxy
  def check_vpn_proxy
    return 0 unless context[:ip_address]
    
    if vpn_detected?(context[:ip_address])
      add_risk_factor("VPN/Proxy detected", 15)
      15
    else
      0
    end
  end
  
  # Check velocity (rate of actions)
  def check_velocity
    return 0 unless user
    
    # Check actions in last hour
    recent_checks = FraudCheck.where(user: user)
                              .where('created_at > ?', 1.hour.ago)
                              .count
    
    if recent_checks > 50
      add_risk_factor("Extremely high activity rate (#{recent_checks}/hour)", 30)
      30
    elsif recent_checks > 20
      add_risk_factor("High activity rate (#{recent_checks}/hour)", 15)
      15
    elsif recent_checks > 10
      add_risk_factor("Elevated activity rate", 5)
      5
    else
      0
    end
  end
  
  # Check behavioral patterns
  def check_patterns
    return 0 unless user
    
    anomalous_patterns = BehavioralPattern.where(user: user)
                                         .anomalous
                                         .recent
                                         .count
    
    if anomalous_patterns > 3
      add_risk_factor("Multiple anomalous behavior patterns (#{anomalous_patterns})", 20)
      20
    elsif anomalous_patterns > 0
      add_risk_factor("Anomalous behavior detected", 10)
      10
    else
      0
    end
  end
  
  # Check for anomalies
  def check_anomalies
    return 0 unless user
    
    # Check for unusual time of activity
    hour = Time.current.hour
    if hour >= 2 && hour <= 5
      add_risk_factor("Unusual time of activity (#{hour}:00)", 5)
      return 5
    end
    
    0
  end
  
  # Check transaction amount
  def check_transaction_amount
    return 0 unless checkable.respond_to?(:total_cents)
    
    amount = checkable.total_cents / 100.0
    
    # Check if amount is unusually high
    if user
      avg_order = user.orders.average(:total_cents).to_f / 100.0
      
      if amount > avg_order * 5 && amount > 500
        add_risk_factor("Transaction amount significantly higher than average", 15)
        return 15
      elsif amount > avg_order * 3 && amount > 300
        add_risk_factor("Transaction amount higher than usual", 10)
        return 10
      end
    end
    
    # Check absolute amount
    if amount > 5000
      add_risk_factor("Very high transaction amount ($#{amount})", 10)
      10
    elsif amount > 2000
      add_risk_factor("High transaction amount", 5)
      5
    else
      0
    end
  end
  
  # Check payment method
  def check_payment_method
    # This would integrate with payment processor
    # For now, return 0
    0
  end
  
  # Check content for spam
  def check_content_spam
    return 0 unless checkable.respond_to?(:content)
    
    content = checkable.content.to_s
    
    # Check for spam patterns
    spam_score = SpamDetector.analyze(content)
    
    if spam_score > 80
      add_risk_factor("High spam score in content", 25)
      25
    elsif spam_score > 50
      add_risk_factor("Moderate spam indicators", 10)
      10
    else
      0
    end
  end
  
  # Helper methods
  
  def add_risk_factor(description, weight)
    @risk_factors << { factor: description, weight: weight }
  end
  
  def ip_blacklisted?(ip)
    # Check against IP blacklist
    # This would integrate with external service
    false
  end
  
  def vpn_detected?(ip)
    # Check if IP is from VPN/Proxy
    # This would integrate with external service like IPQualityScore
    false
  end
  
  # Take action based on risk level
  def take_action(fraud_check)
    case fraud_check.risk_level.to_sym
    when :critical
      fraud_check.update!(action_taken: :account_suspended)
      user.update!(suspended: true, suspended_until: 7.days.from_now)
      FraudAlertMailer.critical_fraud_detected(fraud_check).deliver_later
    when :high
      fraud_check.update!(action_taken: :flagged_for_review)
      FraudAlertMailer.high_risk_detected(fraud_check).deliver_later
    when :medium
      fraud_check.update!(action_taken: :requires_verification)
    end
  end
end

