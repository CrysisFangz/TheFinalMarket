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
    prediction_service.predict_next_purchase
  end

  # Get emotional state (sentiment analysis)
  def emotional_state
    analytics_service.emotional_state
  end

  # Additional methods that delegate to services
  def predict_lifetime_value(timeframe_months = 12)
    prediction_service.predict_lifetime_value(timeframe_months)
  end

  def predict_churn_probability
    prediction_service.predict_churn_probability
  end

  def predict_preferred_channels
    prediction_service.predict_preferred_channels
  end

  def behavioral_insights
    analytics_service.behavioral_insights
  end

  def engagement_score
    analytics_service.engagement_score
  end

  def user_segmentation_data
    analytics_service.user_segmentation_data
  end

  def recommendation_insights
    analytics_service.recommendation_insights
  end

  private

  def prediction_service
    @prediction_service ||= PersonalizationPredictionService.new(self)
  end

  def analytics_service
    @analytics_service ||= PersonalizationAnalyticsService.new(self)
  end
end

