class ReviewInvitationPresenter
  include CircuitBreaker
  include Retryable

  def initialize(invitation)
    @invitation = invitation
  end

  def as_json(options = {})
    cache_key = "review_invitation_presenter:#{@invitation.id}:#{@invitation.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      with_circuit_breaker('review_invitation_presenter') do
        with_retry do
          {
            id: @invitation.id,
            token: @invitation.token,
            status: @invitation.status,
            expires_at: @invitation.expires_at,
            created_at: @invitation.created_at,
            updated_at: @invitation.updated_at,
            days_remaining: days_remaining,
            is_expired: @invitation.expired?,
            is_active: @invitation.active?,
            user: user_data,
            order: order_data,
            item: item_data,
            review: review_data,
            expiry_status: expiry_status
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

  def to_user_response
    as_json.merge(
      user_actions: {
        can_extend: can_extend?,
        can_complete: can_complete?,
        can_resend: can_resend?,
        days_until_expiry: days_remaining
      }
    )
  end

  def to_admin_response
    as_json.merge(
      admin_data: {
        review_submitted: review_submitted?,
        review_rating: review_rating,
        review_content_length: review_content_length,
        time_to_completion: time_to_completion,
        invitation_effectiveness: invitation_effectiveness
      }
    )
  end

  private

  def days_remaining
    return 0 if @invitation.expired? || @invitation.completed?

    [(Time.current - @invitation.expires_at).to_i / 86400, 0].max
  end

  def expiry_status
    Rails.cache.fetch("invitation_expiry_status:#{@invitation.id}", expires_in: 10.minutes) do
      with_circuit_breaker('expiry_status') do
        with_retry do
          if @invitation.completed?
            'completed'
          elsif @invitation.expired?
            'expired'
          elsif days_remaining <= 3
            'expiring_soon'
          elsif days_remaining <= 7
            'expiring_moderately'
          else
            'active'
          end
        end
      end
    end
  end

  def user_data
    Rails.cache.fetch("invitation_user:#{@invitation.user_id}", expires_in: 30.minutes) do
      with_circuit_breaker('user_data') do
        with_retry do
          {
            id: @invitation.user.id,
            username: @invitation.user.username,
            email: @invitation.user.email,
            total_reviews: @invitation.user.reviews.count,
            pending_invitations: ReviewInvitationService.get_pending_count(@invitation.user_id)
          }
        end
      end
    end
  end

  def order_data
    Rails.cache.fetch("invitation_order:#{@invitation.order_id}", expires_in: 15.minutes) do
      with_circuit_breaker('order_data') do
        with_retry do
          {
            id: @invitation.order.id,
            status: @invitation.order.status,
            total: @invitation.order.total,
            completed_at: @invitation.order.completed_at,
            days_since_completion: @invitation.order.completed_at ? (Time.current - @invitation.order.completed_at).to_i / 86400 : nil
          }
        end
      end
    end
  end

  def item_data
    Rails.cache.fetch("invitation_item:#{@invitation.item_id}", expires_in: 15.minutes) do
      with_circuit_breaker('item_data') do
        with_retry do
          rating_info = ReviewRatingService.get_reviewable_rating('Item', @invitation.item_id)

          {
            id: @invitation.item.id,
            name: @invitation.item.name,
            price: @invitation.item.price,
            average_rating: rating_info[:average_rating],
            total_reviews: rating_info[:total_reviews],
            seller_id: @invitation.item.user_id
          }
        end
      end
    end
  end

  def review_data
    return nil unless @invitation.review

    Rails.cache.fetch("invitation_review:#{@invitation.review_id}", expires_in: 15.minutes) do
      with_circuit_breaker('review_data') do
        with_retry do
          {
            id: @invitation.review.id,
            rating: @invitation.review.rating,
            content_length: @invitation.review.content.length,
            helpful_count: @invitation.review.helpful_count,
            created_at: @invitation.review.created_at,
            days_after_invitation: (@invitation.review.created_at - @invitation.created_at).to_i / 86400
          }
        end
      end
    end
  end

  def can_extend?
    @invitation.pending? && days_remaining <= 7
  end

  def can_complete?
    @invitation.pending? && @invitation.review.present?
  end

  def can_resend?
    @invitation.pending? && days_remaining > 0
  end

  def review_submitted?
    @invitation.review.present?
  end

  def review_rating
    @invitation.review&.rating
  end

  def review_content_length
    @invitation.review&.content&.length || 0
  end

  def time_to_completion
    return nil unless @invitation.review

    (@invitation.review.created_at - @invitation.created_at).to_i / 86400
  end

  def invitation_effectiveness
    return 'pending' unless @invitation.review

    if time_to_completion <= 7
      'highly_effective'
    elsif time_to_completion <= 14
      'effective'
    else
      'low_effectiveness'
    end
  end
end