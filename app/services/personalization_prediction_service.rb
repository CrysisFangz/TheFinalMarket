class PersonalizationPredictionService
  attr_reader :profile

  def initialize(profile)
    @profile = profile
  end

  def predict_next_purchase
    Rails.logger.debug("Predicting next purchase for user ID: #{profile.user_id}")

    begin
      return nil if profile.purchase_history.blank?

      # Calculate average days between purchases
      days_between = calculate_days_between_purchases
      last_purchase = profile.purchase_history.last[:date]

      prediction = {
        predicted_date: last_purchase + days_between.days,
        confidence: calculate_prediction_confidence,
        likely_categories: top_categories.first(3),
        likely_price_range: predict_price_range
      }

      Rails.logger.info("Generated purchase prediction for user ID: #{profile.user_id}: #{prediction}")
      prediction
    rescue => e
      Rails.logger.error("Failed to predict next purchase for user ID: #{profile.user_id}. Error: #{e.message}")
      nil
    end
  end

  def predict_lifetime_value(timeframe_months = 12)
    Rails.logger.debug("Predicting lifetime value for user ID: #{profile.user_id}, timeframe: #{timeframe_months} months")

    begin
      return 0 if profile.purchase_history.blank?

      monthly_value = calculate_monthly_value
      predicted_value = monthly_value * timeframe_months

      # Apply churn probability
      churn_rate = calculate_churn_probability
      retention_factor = 1 - churn_rate

      final_prediction = predicted_value * retention_factor

      prediction = {
        predicted_value: final_prediction.round(2),
        monthly_value: monthly_value.round(2),
        churn_rate: churn_rate.round(2),
        retention_factor: retention_factor.round(2),
        confidence: calculate_ltv_confidence
      }

      Rails.logger.info("Generated LTV prediction for user ID: #{profile.user_id}: #{prediction}")
      prediction
    rescue => e
      Rails.logger.error("Failed to predict lifetime value for user ID: #{profile.user_id}. Error: #{e.message}")
      0
    end
  end

  def predict_churn_probability
    Rails.logger.debug("Predicting churn probability for user ID: #{profile.user_id}")

    begin
      # Analyze user behavior patterns
      recency_score = calculate_recency_score
      frequency_score = calculate_frequency_score
      monetary_score = calculate_monetary_score
      engagement_score = calculate_engagement_score

      # Calculate churn probability based on multiple factors
      churn_factors = [
        (100 - recency_score) * 0.3,
        (100 - frequency_score) * 0.25,
        (100 - monetary_score) * 0.2,
        (100 - engagement_score) * 0.25
      ]

      churn_probability = churn_factors.sum / 100.0

      # Cap between 0 and 1
      churn_probability = [0, [1, churn_probability].min].max

      Rails.logger.debug("Calculated churn probability for user ID: #{profile.user_id}: #{churn_probability}")
      churn_probability
    rescue => e
      Rails.logger.error("Failed to predict churn probability for user ID: #{profile.user_id}. Error: #{e.message}")
      0.5 # Default to 50% if calculation fails
    end
  end

  def predict_preferred_channels
    Rails.logger.debug("Predicting preferred channels for user ID: #{profile.user_id}")

    begin
      channel_preferences = {}

      # Analyze interaction patterns across channels
      profile.behavioral_events.where('created_at > ?', 90.days.ago).each do |event|
        channel = event.channel || 'unknown'
        channel_preferences[channel] ||= 0
        channel_preferences[channel] += event.interaction_score || 1
      end

      # Sort by preference score
      preferred_channels = channel_preferences.sort_by { |_, score| -score }.map(&:first).first(3)

      Rails.logger.debug("Predicted preferred channels for user ID: #{profile.user_id}: #{preferred_channels}")
      preferred_channels
    rescue => e
      Rails.logger.error("Failed to predict preferred channels for user ID: #{profile.user_id}. Error: #{e.message}")
      []
    end
  end

  private

  def calculate_days_between_purchases
    Rails.logger.debug("Calculating days between purchases for user ID: #{profile.user_id}")

    begin
      return 30 if profile.purchase_history.count < 2

      dates = profile.purchase_history.map { |p| p[:date] }.sort
      intervals = dates.each_cons(2).map { |a, b| (b - a) / 1.day }
      average_interval = intervals.sum / intervals.count.to_f

      Rails.logger.debug("Calculated average days between purchases for user ID: #{profile.user_id}: #{average_interval}")
      average_interval
    rescue => e
      Rails.logger.error("Failed to calculate days between purchases for user ID: #{profile.user_id}. Error: #{e.message}")
      30 # Default to 30 days
    end
  end

  def calculate_prediction_confidence
    Rails.logger.debug("Calculating prediction confidence for user ID: #{profile.user_id}")

    begin
      purchase_count = profile.purchase_history&.count || 0

      confidence = if purchase_count > 10
        90
      elsif purchase_count > 5
        70
      elsif purchase_count > 2
        50
      else
        30
      end

      Rails.logger.debug("Calculated prediction confidence for user ID: #{profile.user_id}: #{confidence}")
      confidence
    rescue => e
      Rails.logger.error("Failed to calculate prediction confidence for user ID: #{profile.user_id}. Error: #{e.message}")
      30
    end
  end

  def predict_price_range
    Rails.logger.debug("Predicting price range for user ID: #{profile.user_id}")

    begin
      return [0, 10000] if profile.purchase_history.blank?

      prices = profile.purchase_history.map { |p| p[:total] }
      avg = prices.sum / prices.count.to_f

      price_range = [(avg * 0.7).to_i, (avg * 1.3).to_i]

      Rails.logger.debug("Predicted price range for user ID: #{profile.user_id}: #{price_range}")
      price_range
    rescue => e
      Rails.logger.error("Failed to predict price range for user ID: #{profile.user_id}. Error: #{e.message}")
      [0, 10000]
    end
  end

  def top_categories
    Rails.logger.debug("Getting top categories for user ID: #{profile.user_id}")

    begin
      categories = (profile.product_interests || {}).sort_by { |k, v| -v }.map(&:first).first(5)

      Rails.logger.debug("Got top categories for user ID: #{profile.user_id}: #{categories}")
      categories
    rescue => e
      Rails.logger.error("Failed to get top categories for user ID: #{profile.user_id}. Error: #{e.message}")
      []
    end
  end

  def calculate_monthly_value
    Rails.logger.debug("Calculating monthly value for user ID: #{profile.user_id}")

    begin
      return 0 if profile.purchase_history.blank?

      first_purchase = profile.purchase_history.first[:date]
      months_active = (Time.current - first_purchase) / 30.0
      return 0 if months_active.zero?

      total_value = profile.purchase_history.sum { |p| p[:total] }
      monthly_value = total_value / months_active

      Rails.logger.debug("Calculated monthly value for user ID: #{profile.user_id}: #{monthly_value}")
      monthly_value
    rescue => e
      Rails.logger.error("Failed to calculate monthly value for user ID: #{profile.user_id}. Error: #{e.message}")
      0
    end
  end

  def calculate_churn_probability
    # This method is defined above but called here - avoiding duplication
    predict_churn_probability
  end

  def calculate_recency_score
    # Calculate based on last activity
    last_activity = profile.behavioral_events.maximum(:created_at) || profile.updated_at
    days_since = (Time.current - last_activity).to_i

    case days_since
    when 0..7 then 100
    when 8..30 then 75
    when 31..90 then 50
    when 91..180 then 25
    else 0
    end
  end

  def calculate_frequency_score
    # Calculate based on activity frequency
    recent_events = profile.behavioral_events.where('created_at > ?', 30.days.ago).count

    case recent_events
    when 0..2 then 20
    when 3..10 then 50
    when 11..25 then 75
    else 100
    end
  end

  def calculate_monetary_score
    # Calculate based on purchase value
    return 0 if profile.purchase_history.blank?

    avg_purchase = profile.purchase_history.sum { |p| p[:total] } / profile.purchase_history.count.to_f

    case avg_purchase
    when 0..50 then 20
    when 51..200 then 50
    when 201..1000 then 75
    else 100
    end
  end

  def calculate_engagement_score
    # Calculate based on various engagement metrics
    engagement_factors = []

    # Product views
    views_count = profile.behavioral_events.where(event_type: 'product_view').count
    engagement_factors << (views_count > 10 ? 100 : views_count * 10)

    # Wishlist additions
    wishlist_count = profile.behavioral_events.where(event_type: 'wishlist_add').count
    engagement_factors << (wishlist_count > 5 ? 100 : wishlist_count * 20)

    # Reviews written
    reviews_count = profile.user.reviews.count
    engagement_factors << (reviews_count > 3 ? 100 : reviews_count * 33)

    engagement_factors.sum / engagement_factors.length
  end

  def calculate_ltv_confidence
    # Calculate confidence in LTV prediction
    purchase_count = profile.purchase_history&.count || 0
    months_active = profile.purchase_history&.first ? (Time.current - profile.purchase_history.first[:date]) / 30 : 0

    if purchase_count > 10 && months_active > 6
      90
    elsif purchase_count > 5 && months_active > 3
      70
    elsif purchase_count > 2
      50
    else
      30
    end
  end
end