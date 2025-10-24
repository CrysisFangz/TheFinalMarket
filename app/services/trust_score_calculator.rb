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

    score = case age_days.to_i
            when 0..7 then 0
            when 8..30 then 2
            when 31..90 then 4
            when 91..180 then 6
            when 181..365 then 8
            else 10
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
    # Preload associations for efficiency
    user_orders = user.orders
    user_reviews = user.reviews

    login_count = user.respond_to?(:sign_in_count) ? user.sign_in_count : 0
    order_count = user_orders.count
    review_count = user_reviews.count

    total_activity = login_count + (order_count * 5) + (review_count * 3)

    score = case total_activity
            when 0..5 then 0
            when 6..10 then 2
            when 11..20 then 4
            when 21..50 then 6
            when 51..100 then 8
            else 10
            end

    add_factor("Activity level: #{total_activity} actions", score)
    @details[:total_activity] = total_activity
    score
  end
  
  # Reputation score (0-15 points)
  def reputation_score
    return 0 unless user.respond_to?(:reputation_score)

    rep = user.reputation_score

    score = case rep
            when 0..29 then 2
            when 30..49 then 5
            when 50..69 then 8
            when 70..89 then 12
            else 15
            end

    add_factor("Reputation: #{rep}/100", score)
    @details[:reputation] = rep
    score
  end
  
  # Transaction history (0-15 points)
  def transaction_history_score
    # Preload completed orders for efficiency
    completed_orders = user.orders.where(status: 'completed')
    completed_count = completed_orders.count
    total_spent = completed_orders.sum(:total_cents) / 100.0

    score = 0

    # Points for completed orders
    score += case completed_count
             when 0..5 then 0
             when 6..10 then 2
             when 11..20 then 4
             when 21..50 then 6
             else 8
             end

    # Points for total spent
    score += case total_spent
             when 0..500 then 0
             when 501..1000 then 2
             when 1001..2000 then 3
             when 2001..5000 then 5
             else 7
             end

    add_factor("#{completed_count} completed orders, $#{total_spent.round(2)} spent", score)
    @details[:completed_orders] = completed_count
    @details[:total_spent] = total_spent
    score
  end
  
  # Social proof (0-10 points)
  def social_proof_score
    score = 0

    # Positive reviews received
    if user.respond_to?(:received_reviews)
      positive_reviews = user.received_reviews.where('rating >= ?', 4).count

      score += case positive_reviews
               when 0 then 0
               when 1..5 then 1
               when 6..10 then 2
               when 11..20 then 3
               when 21..50 then 4
               else 5
               end

      @details[:positive_reviews] = positive_reviews
    end

    # Followers/connections
    if user.respond_to?(:followers_count)
      followers = user.followers_count

      score += case followers
               when 0 then 0
               when 1..10 then 1
               when 11..50 then 2
               when 51..100 then 3
               else 5
               end

      @details[:followers] = followers
    end

    add_factor("Social proof score", score) if score > 0
    score
  end
  
  # Fraud history (0-30 points deduction)
  def fraud_history_score
    fraud_flags = FraudCheck.where(user: user).flagged.count

    score = case fraud_flags
            when 0 then 0
            when 1..2 then 5
            when 3..5 then 10
            when 6..10 then 20
            else 30
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

    disputes = user.disputes_against
    disputes_count = disputes.count
    lost_disputes_count = disputes.where(resolution: 'resolved_against_reported').count

    score = if lost_disputes_count > 5
      20
    elsif lost_disputes_count > 2
      15
    elsif lost_disputes_count > 0
      10
    elsif disputes_count > 5
      5
    else
      0
    end

    if score > 0
      add_factor("#{disputes_count} disputes (#{lost_disputes_count} lost)", -score)
      @details[:disputes] = disputes_count
      @details[:lost_disputes] = lost_disputes_count
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
      suspension_count = user.suspension_count
      score = [suspension_count * 10, 20].min
      add_factor("#{suspension_count} previous suspensions", -score)
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

