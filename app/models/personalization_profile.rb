class PersonalizationProfile < ApplicationRecord
  belongs_to :user
  
  has_many :user_segments, dependent: :destroy
  has_many :personalized_recommendations, dependent: :destroy
  has_many :behavioral_events, dependent: :destroy
  
  validates :user, presence: true
  
  # Update profile based on behavior
  def update_from_behavior(event_type, data = {})
    case event_type.to_sym
    when :product_view
      track_product_interest(data[:product])
    when :search
      track_search_interest(data[:query])
    when :purchase
      track_purchase_behavior(data[:order])
    when :cart_add
      track_cart_behavior(data[:product])
    when :wishlist_add
      track_wishlist_behavior(data[:product])
    end
    
    # Update segments
    update_segments
    
    # Recalculate scores
    recalculate_scores
  end
  
  # Get personalized recommendations
  def get_recommendations(context = {})
    recommendations = []
    
    # Collaborative filtering
    recommendations += collaborative_filtering_recommendations
    
    # Content-based filtering
    recommendations += content_based_recommendations
    
    # Contextual recommendations
    recommendations += contextual_recommendations(context)
    
    # Trending items
    recommendations += trending_recommendations
    
    # Deduplicate and score
    recommendations.uniq { |r| r[:product_id] }
                  .sort_by { |r| -r[:score] }
                  .first(20)
  end
  
  # Get micro-segment
  def micro_segment
    segments = []
    
    # Behavioral segments
    segments << "high_value" if lifetime_value_score > 80
    segments << "frequent_buyer" if purchase_frequency_score > 70
    segments << "deal_seeker" if price_sensitivity_score > 60
    segments << "brand_loyal" if brand_loyalty_score > 70
    segments << "impulse_buyer" if impulse_buying_score > 60
    segments << "researcher" if research_intensity_score > 70
    
    # Category preferences
    top_categories.each do |category|
      segments << "#{category}_enthusiast"
    end
    
    # Time-based
    segments << "weekend_shopper" if weekend_shopping_score > 60
    segments << "night_owl" if night_shopping_score > 60
    
    # Device preference
    segments << "mobile_first" if mobile_usage_score > 70
    
    segments
  end
  
  # Predict next purchase
  def predict_next_purchase
    return nil if purchase_history.empty?
    
    # Calculate average days between purchases
    days_between = calculate_days_between_purchases
    last_purchase = purchase_history.last[:date]
    
    {
      predicted_date: last_purchase + days_between.days,
      confidence: calculate_prediction_confidence,
      likely_categories: top_categories.first(3),
      likely_price_range: predict_price_range
    }
  end
  
  # Get emotional state (sentiment analysis)
  def emotional_state
    recent_reviews = user.reviews.where('created_at > ?', 30.days.ago)
    
    return 'neutral' if recent_reviews.empty?
    
    avg_rating = recent_reviews.average(:rating).to_f
    
    if avg_rating >= 4.5
      'very_satisfied'
    elsif avg_rating >= 4.0
      'satisfied'
    elsif avg_rating >= 3.0
      'neutral'
    elsif avg_rating >= 2.0
      'dissatisfied'
    else
      'very_dissatisfied'
    end
  end
  
  private
  
  def track_product_interest(product)
    interests = product_interests || {}
    category = product.category
    
    interests[category] ||= 0
    interests[category] += 1
    
    update!(product_interests: interests)
  end
  
  def track_search_interest(query)
    searches = search_history || []
    searches << { query: query, timestamp: Time.current }
    searches = searches.last(100) # Keep last 100 searches
    
    update!(search_history: searches)
  end
  
  def track_purchase_behavior(order)
    purchases = purchase_history || []
    purchases << {
      order_id: order.id,
      total: order.total_cents,
      date: order.created_at,
      categories: order.line_items.map { |li| li.product.category }.uniq
    }
    
    update!(
      purchase_history: purchases,
      last_purchase_at: order.created_at
    )
  end
  
  def track_cart_behavior(product)
    cart_items = cart_history || []
    cart_items << {
      product_id: product.id,
      category: product.category,
      price: product.price_cents,
      timestamp: Time.current
    }
    
    update!(cart_history: cart_items.last(100))
  end
  
  def track_wishlist_behavior(product)
    wishlist_items = wishlist_history || []
    wishlist_items << {
      product_id: product.id,
      category: product.category,
      timestamp: Time.current
    }
    
    update!(wishlist_history: wishlist_items.last(100))
  end
  
  def update_segments
    current_segments = micro_segment
    
    current_segments.each do |segment_name|
      user_segments.find_or_create_by!(segment_name: segment_name)
    end
    
    # Remove old segments
    user_segments.where.not(segment_name: current_segments).destroy_all
  end
  
  def recalculate_scores
    update!(
      lifetime_value_score: calculate_ltv_score,
      purchase_frequency_score: calculate_frequency_score,
      price_sensitivity_score: calculate_price_sensitivity,
      brand_loyalty_score: calculate_brand_loyalty,
      impulse_buying_score: calculate_impulse_score,
      research_intensity_score: calculate_research_score,
      weekend_shopping_score: calculate_weekend_score,
      night_shopping_score: calculate_night_score,
      mobile_usage_score: calculate_mobile_score
    )
  end
  
  def collaborative_filtering_recommendations
    # Find similar users
    similar_users = find_similar_users
    
    # Get products they bought that this user hasn't
    Product.joins(:orders)
          .where(orders: { user_id: similar_users.map(&:id) })
          .where.not(id: user.orders.joins(:line_items).select('line_items.product_id'))
          .distinct
          .limit(10)
          .map { |p| { product_id: p.id, score: 70, reason: 'similar_users' } }
  end
  
  def content_based_recommendations
    # Based on user's interests
    top_cats = top_categories.first(3)
    
    Product.where(category: top_cats)
          .where.not(id: user.orders.joins(:line_items).select('line_items.product_id'))
          .order('RANDOM()')
          .limit(10)
          .map { |p| { product_id: p.id, score: 60, reason: 'category_match' } }
  end
  
  def contextual_recommendations(context)
    recommendations = []
    
    # Weather-based
    if context[:weather] == 'rainy'
      recommendations += Product.where(category: ['Umbrellas', 'Raincoats']).limit(5)
                               .map { |p| { product_id: p.id, score: 80, reason: 'weather' } }
    end
    
    # Time-based
    if context[:time_of_day] == 'morning'
      recommendations += Product.where(category: ['Coffee', 'Breakfast']).limit(5)
                               .map { |p| { product_id: p.id, score: 75, reason: 'time_of_day' } }
    end
    
    # Location-based
    if context[:location]
      # Local products
    end
    
    recommendations
  end
  
  def trending_recommendations
    Product.order('views_count DESC')
          .limit(5)
          .map { |p| { product_id: p.id, score: 50, reason: 'trending' } }
  end
  
  def top_categories
    (product_interests || {}).sort_by { |k, v| -v }.map(&:first).first(5)
  end
  
  def find_similar_users
    # Simple similarity based on purchase categories
    my_categories = purchase_history&.flat_map { |p| p[:categories] }&.uniq || []
    
    User.joins(:orders)
        .where.not(id: user.id)
        .select('users.*, COUNT(DISTINCT orders.id) as order_count')
        .group('users.id')
        .having('COUNT(DISTINCT orders.id) > 3')
        .limit(10)
  end
  
  def calculate_ltv_score
    total_spent = purchase_history&.sum { |p| p[:total] } || 0
    [total_spent / 10000.0, 100].min.round
  end
  
  def calculate_frequency_score
    return 0 if purchase_history.blank?
    
    purchases_per_month = purchase_history.count / 12.0
    [purchases_per_month * 20, 100].min.round
  end
  
  def calculate_price_sensitivity
    return 50 if purchase_history.blank?
    
    avg_price = purchase_history.sum { |p| p[:total] } / purchase_history.count.to_f
    avg_price < 5000 ? 80 : 30
  end
  
  def calculate_brand_loyalty
    # Simplified - would check brand repetition
    50
  end
  
  def calculate_impulse_score
    # Check time between view and purchase
    50
  end
  
  def calculate_research_score
    search_count = search_history&.count || 0
    [search_count / 10.0 * 100, 100].min.round
  end
  
  def calculate_weekend_score
    return 50 if purchase_history.blank?
    
    weekend_purchases = purchase_history.count { |p| [0, 6].include?(p[:date].wday) }
    (weekend_purchases.to_f / purchase_history.count * 100).round
  end
  
  def calculate_night_score
    return 50 if purchase_history.blank?
    
    night_purchases = purchase_history.count { |p| p[:date].hour >= 20 || p[:date].hour < 6 }
    (night_purchases.to_f / purchase_history.count * 100).round
  end
  
  def calculate_mobile_score
    # Would check device usage
    60
  end
  
  def calculate_days_between_purchases
    return 30 if purchase_history.count < 2
    
    dates = purchase_history.map { |p| p[:date] }.sort
    intervals = dates.each_cons(2).map { |a, b| (b - a) / 1.day }
    intervals.sum / intervals.count.to_f
  end
  
  def calculate_prediction_confidence
    purchase_count = purchase_history&.count || 0
    
    if purchase_count > 10
      90
    elsif purchase_count > 5
      70
    elsif purchase_count > 2
      50
    else
      30
    end
  end
  
  def predict_price_range
    return [0, 10000] if purchase_history.blank?
    
    prices = purchase_history.map { |p| p[:total] }
    avg = prices.sum / prices.count.to_f
    
    [(avg * 0.7).to_i, (avg * 1.3).to_i]
  end
end

