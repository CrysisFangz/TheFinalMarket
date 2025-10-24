class ReviewPresenter
  include CircuitBreaker
  include Retryable

  def initialize(review)
    @review = review
  end

  def as_json(options = {})
    cache_key = "review_presenter:#{@review.id}:#{@review.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      with_circuit_breaker('review_presenter') do
        with_retry do
          {
            id: @review.id,
            rating: @review.rating,
            content: @review.content,
            pros: @review.pros,
            cons: @review.cons,
            helpful_count: @review.helpful_count,
            created_at: @review.created_at,
            updated_at: @review.updated_at,
            reviewer: reviewer_data,
            reviewable: reviewable_data,
            review_invitation: review_invitation_data,
            order: order_data,
            helpful_votes: helpful_votes_data,
            moderation_status: moderation_status,
            points_earned: ReviewRatingService.calculate_review_points(@review)
          }
        end
      end
    end
  end

  def to_api_response
    as_json.merge(
      metadata: {
        cache_timestamp: Time.current,
        version: '1.0'
      }
    )
  end

  def to_moderator_response
    as_json.merge(
      moderation_data: {
        validation_results: moderation_validation_results,
        content_flags: content_analysis,
        risk_score: calculate_risk_score,
        requires_attention: requires_moderation_attention?
      }
    )
  end

  private

  def reviewer_data
    Rails.cache.fetch("review_reviewer:#{@review.reviewer_id}", expires_in: 30.minutes) do
      with_circuit_breaker('reviewer_data') do
        with_retry do
          {
            id: @review.reviewer.id,
            username: @review.reviewer.username,
            reputation_score: @review.reviewer.reputation_score,
            total_reviews: @review.reviewer.reviews.count,
            verified_buyer: @review.reviewer.orders.completed.any?
          }
        end
      end
    end
  end

  def reviewable_data
    Rails.cache.fetch("review_reviewable:#{@review.reviewable_type}:#{@review.reviewable_id}", expires_in: 15.minutes) do
      with_circuit_breaker('reviewable_data') do
        with_retry do
          rating_info = ReviewRatingService.get_reviewable_rating(@review.reviewable_type, @review.reviewable_id)

          {
            id: @review.reviewable_id,
            type: @review.reviewable_type,
            name: @review.reviewable.respond_to?(:name) ? @review.reviewable.name : @review.reviewable.username,
            average_rating: rating_info[:average_rating],
            total_reviews: rating_info[:total_reviews],
            rating_distribution: rating_info[:rating_distribution]
          }
        end
      end
    end
  end

  def review_invitation_data
    return nil unless @review.review_invitation

    Rails.cache.fetch("review_invitation:#{@review.review_invitation_id}", expires_in: 30.minutes) do
      with_circuit_breaker('review_invitation_data') do
        with_retry do
          {
            id: @review.review_invitation.id,
            invited_at: @review.review_invitation.created_at,
            expires_at: @review.review_invitation.expires_at,
            invitation_type: @review.review_invitation.invitation_type
          }
        end
      end
    end
  end

  def order_data
    return nil unless @review.order

    Rails.cache.fetch("review_order:#{@review.order_id}", expires_in: 15.minutes) do
      with_circuit_breaker('order_data') do
        with_retry do
          {
            id: @review.order.id,
            status: @review.order.status,
            total: @review.order.total,
            completed_at: @review.order.completed_at,
            days_since_completion: @review.order.completed_at ? (Time.current - @review.order.completed_at).to_i / 86400 : nil
          }
        end
      end
    end
  end

  def helpful_votes_data
    Rails.cache.fetch("review_helpful_votes:#{@review.id}", expires_in: 10.minutes) do
      with_circuit_breaker('helpful_votes_data') do
        with_retry do
          ReviewManagementService.get_helpful_votes(@review.id)
        end
      end
    end
  end

  def moderation_status
    Rails.cache.fetch("review_moderation_status:#{@review.id}", expires_in: 20.minutes) do
      with_circuit_breaker('moderation_status') do
        with_retry do
          {
            is_validated: @review.errors.empty?,
            validation_errors: @review.errors.full_messages,
            content_quality_score: calculate_content_quality_score,
            spam_probability: calculate_spam_probability
          }
        end
      end
    end
  end

  def moderation_validation_results
    {
      ownership_valid: ReviewModerationService.validate_review_ownership(@review),
      purchase_valid: @review.item_review? ? ReviewModerationService.validate_purchase_requirement(@review) : true,
      seller_transaction_valid: @review.seller_review? ? ReviewModerationService.validate_seller_transaction(@review) : true,
      dispute_valid: ReviewModerationService.validate_dispute_status(@review),
      content_quality_valid: ReviewModerationService.validate_content_quality(@review)
    }
  end

  def content_analysis
    {
      word_count: @review.content.split.size,
      has_pros: @review.pros.present?,
      has_cons: @review.cons.present?,
      contains_links: @review.content.include?('http'),
      contains_mentions: @review.content.include?('@'),
      sentiment_score: calculate_sentiment_score
    }
  end

  def calculate_risk_score
    score = 0
    score += 20 if @review.content.length < 20
    score += 15 if @review.content.include?('http')
    score += 10 if @review.rating == 5 && @review.content.length < 50
    score += 25 if calculate_spam_probability > 0.7
    score
  end

  def requires_moderation_attention?
    calculate_risk_score > 30 || calculate_spam_probability > 0.6
  end

  def calculate_content_quality_score
    score = 50 # Base score
    score += 10 if @review.content.length >= 100
    score += 10 if @review.content.length >= 200
    score += 5 if @review.pros.present?
    score += 5 if @review.cons.present?
    score += 10 if @review.rating.between?(2, 4) # Balanced rating
    score
  end

  def calculate_spam_probability
    spam_indicators = 0
    total_indicators = 5

    spam_indicators += 1 if @review.content.length < 30
    spam_indicators += 1 if @review.content.include?('buy now') || @review.content.include?('click here')
    spam_indicators += 1 if @review.rating == 5 && @review.content.length < 50
    spam_indicators += 1 if @review.content.count('!') > 3
    spam_indicators += 1 if @review.content.include?('http')

    spam_indicators.to_f / total_indicators
  end

  def calculate_sentiment_score
    # Simple sentiment analysis based on positive/negative words
    positive_words = ['good', 'great', 'excellent', 'amazing', 'perfect', 'love', 'awesome']
    negative_words = ['bad', 'terrible', 'awful', 'hate', 'worst', 'disappointing', 'poor']

    words = @review.content.downcase.split
    positive_count = words.count { |word| positive_words.include?(word) }
    negative_count = words.count { |word| negative_words.include?(word) }

    total_sentiment_words = positive_count + negative_count
    return 0 if total_sentiment_words.zero?

    (positive_count.to_f / total_sentiment_words) * 100
  end
end