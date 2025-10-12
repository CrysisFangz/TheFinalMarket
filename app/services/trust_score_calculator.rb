class TrustScoreCalculator
  attr_reader :user, :factors, :details
  
  def initialize(user)
    @user = user
    @factors = { factors: [] }
    @details = {}
  end
  
  # Calculate trust score (0-100)
  def calculate
    score = 50 # Start at neutral
    
    # Positive factors (increase trust)
    score += account_age_score
    score += verification_score
    score += activity_score
    score += reputation_score
    score += transaction_history_score
    score += social_proof_score
    
    # Negative factors (decrease trust)
    score -= fraud_history_score
    score -= dispute_score
    score -= suspension_score
    
    # Ensure score is between 0 and 100
    [[score, 0].max, 100].min
  end
  
  private
  
  # Account age (0-10 points)
  def account_age_score
    age_days = (Time.current - user.created_at) / 1.day
    
    score = if age_days > 365
      10
    elsif age_days > 180
      8
    elsif age_days > 90
      6
    elsif age_days > 30
      4
    elsif age_days > 7
      2
    else
      0
    end
    
    add_factor("Account age: #{age_days.to_i} days", score)
    @details[:account_age_days] = age_days.to_i
    score
  end
  
  # Verification status (0-15 points)
  def verification_score
    score = 0
    
    if user.email_verified?
      score += 5
      add_factor("Email verified", 5)
    end
    
    if user.respond_to?(:phone_verified?) && user.phone_verified?
      score += 5
      add_factor("Phone verified", 5)
    end
    
    if user.respond_to?(:identity_verified?) && user.identity_verified?
      score += 5
      add_factor("Identity verified", 5)
    end
    
    @details[:verification_score] = score
    score
  end
  
  # Activity level (0-10 points)
  def activity_score
    # Count various activities
    login_count = user.respond_to?(:sign_in_count) ? user.sign_in_count : 0
    order_count = user.orders.count
    review_count = user.reviews.count
    
    total_activity = login_count + (order_count * 5) + (review_count * 3)
    
    score = if total_activity > 100
      10
    elsif total_activity > 50
      8
    elsif total_activity > 20
      6
    elsif total_activity > 10
      4
    elsif total_activity > 5
      2
    else
      0
    end
    
    add_factor("Activity level: #{total_activity} actions", score)
    @details[:total_activity] = total_activity
    score
  end
  
  # Reputation score (0-15 points)
  def reputation_score
    return 0 unless user.respond_to?(:reputation_score)
    
    rep = user.reputation_score
    
    score = if rep >= 90
      15
    elsif rep >= 70
      12
    elsif rep >= 50
      8
    elsif rep >= 30
      5
    else
      2
    end
    
    add_factor("Reputation: #{rep}/100", score)
    @details[:reputation] = rep
    score
  end
  
  # Transaction history (0-15 points)
  def transaction_history_score
    completed_orders = user.orders.where(status: 'completed').count
    total_spent = user.orders.where(status: 'completed').sum(:total_cents) / 100.0
    
    score = 0
    
    # Points for completed orders
    if completed_orders > 50
      score += 8
    elsif completed_orders > 20
      score += 6
    elsif completed_orders > 10
      score += 4
    elsif completed_orders > 5
      score += 2
    end
    
    # Points for total spent
    if total_spent > 5000
      score += 7
    elsif total_spent > 2000
      score += 5
    elsif total_spent > 1000
      score += 3
    elsif total_spent > 500
      score += 2
    end
    
    add_factor("#{completed_orders} completed orders, $#{total_spent.round(2)} spent", score)
    @details[:completed_orders] = completed_orders
    @details[:total_spent] = total_spent
    score
  end
  
  # Social proof (0-10 points)
  def social_proof_score
    score = 0
    
    # Positive reviews received
    if user.respond_to?(:received_reviews)
      positive_reviews = user.received_reviews.where('rating >= ?', 4).count
      
      if positive_reviews > 50
        score += 5
      elsif positive_reviews > 20
        score += 4
      elsif positive_reviews > 10
        score += 3
      elsif positive_reviews > 5
        score += 2
      elsif positive_reviews > 0
        score += 1
      end
      
      @details[:positive_reviews] = positive_reviews
    end
    
    # Followers/connections
    if user.respond_to?(:followers_count)
      followers = user.followers_count
      
      if followers > 100
        score += 5
      elsif followers > 50
        score += 3
      elsif followers > 10
        score += 2
      elsif followers > 0
        score += 1
      end
      
      @details[:followers] = followers
    end
    
    add_factor("Social proof score", score) if score > 0
    score
  end
  
  # Fraud history (0-30 points deduction)
  def fraud_history_score
    fraud_flags = FraudCheck.where(user: user).flagged.count
    
    score = if fraud_flags > 10
      30
    elsif fraud_flags > 5
      20
    elsif fraud_flags > 2
      10
    elsif fraud_flags > 0
      5
    else
      0
    end
    
    if score > 0
      add_factor("#{fraud_flags} fraud flags", -score)
      @details[:fraud_flags] = fraud_flags
    end
    
    score
  end
  
  # Dispute history (0-20 points deduction)
  def dispute_score
    return 0 unless user.respond_to?(:disputes_against)
    
    disputes = user.disputes_against.count
    lost_disputes = user.disputes_against.where(resolution: 'resolved_against_reported').count
    
    score = if lost_disputes > 5
      20
    elsif lost_disputes > 2
      15
    elsif lost_disputes > 0
      10
    elsif disputes > 5
      5
    else
      0
    end
    
    if score > 0
      add_factor("#{disputes} disputes (#{lost_disputes} lost)", -score)
      @details[:disputes] = disputes
      @details[:lost_disputes] = lost_disputes
    end
    
    score
  end
  
  # Suspension history (0-25 points deduction)
  def suspension_score
    return 0 unless user.respond_to?(:suspended?)
    
    score = 0
    
    if user.suspended?
      score = 25
      add_factor("Currently suspended", -score)
    elsif user.respond_to?(:suspension_count) && user.suspension_count > 0
      score = user.suspension_count * 10
      score = [score, 20].min
      add_factor("#{user.suspension_count} previous suspensions", -score)
    end
    
    @details[:suspended] = user.suspended?
    score
  end
  
  # Helper method to add factor
  def add_factor(description, points)
    @factors[:factors] << {
      description: description,
      points: points
    }
  end
end

