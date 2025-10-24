class PersonalizationProfile < ApplicationRecord
  belongs_to :user

  has_many :user_segments, dependent: :destroy
  has_many :personalized_recommendations, dependent: :destroy
  has_many :behavioral_events, dependent: :destroy

  validates :user, presence: true
  validates :product_interests, allow_nil: true
  validates :search_history, allow_nil: true
  validates :purchase_history, allow_nil: true
  validates :cart_history, allow_nil: true
  validates :wishlist_history, allow_nil: true

  # Update profile based on behavior
  def update_from_behavior(event_type, data = {})
    PersonalizationService.new(self).update_from_behavior(event_type, data)
  end

  # Get personalized recommendations
  def get_recommendations(context = {})
    cache_key = "recommendations:#{user_id}:#{context.hash}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      RecommendationEngine.new(self).get_recommendations(context)
    end
  end

  # Get micro-segment
  def micro_segment
    cache_key = "segments:#{user_id}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      SegmentManager.new(self).micro_segment
    end
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

  def top_categories
    (product_interests || {}).sort_by { |k, v| -v }.map(&:first).first(5)
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

