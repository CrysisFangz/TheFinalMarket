class ReviewRatingService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'review_rating'
  CACHE_TTL = 15.minutes

  def self.update_reviewable_rating(review)
    cache_key = "#{CACHE_KEY_PREFIX}:update:#{review.reviewable_type}:#{review.reviewable_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_rating') do
        with_retry do
          avg_rating = Review.where(reviewable: review.reviewable).average(:rating) || 0

          if review.reviewable_type == 'User'
            review.reviewable.update(seller_rating: avg_rating)
          else
            review.reviewable.update(rating: avg_rating)
          end

          EventPublisher.publish('review.rating_updated', {
            review_id: review.id,
            reviewable_type: review.reviewable_type,
            reviewable_id: review.reviewable_id,
            new_average_rating: avg_rating,
            total_reviews: Review.where(reviewable: review.reviewable).count
          })

          avg_rating
        end
      end
    end
  end

  def self.award_review_points(review)
    cache_key = "#{CACHE_KEY_PREFIX}:points:#{review.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_rating') do
        with_retry do
          points = calculate_review_points(review)
          review.reviewer.increment!(:points, points)

          # Award points to the item/seller owner for receiving a review
          if review.rating >= 4
            owner_points = review.rating * 5 # More points for better ratings
            review.reviewable.user.increment!(:points, owner_points)

            EventPublisher.publish('review.points_awarded_owner', {
              review_id: review.id,
              owner_id: review.reviewable.user_id,
              owner_points: owner_points,
              rating: review.rating
            })
          end

          EventPublisher.publish('review.points_awarded_reviewer', {
            review_id: review.id,
            reviewer_id: review.reviewer_id,
            points: points,
            rating: review.rating
          })

          points
        end
      end
    end
  end

  def self.calculate_review_points(review)
    cache_key = "#{CACHE_KEY_PREFIX}:calculate_points:#{review.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_rating') do
        with_retry do
          base_points = 10
          points = base_points

          # Bonus points for detailed reviews
          points += 5 if review.content.length >= 100
          points += 5 if review.content.length >= 200
          points += 3 if review.pros.present?
          points += 3 if review.cons.present?

          # Bonus for adding first review
          points += 10 unless Review.exists?(reviewable: review.reviewable)

          # Time bonus for quick reviews after order completion
          if review.order&.completed? && (Time.current - review.order.completed_at) <= 7.days
            points += 5
          end

          points
        end
      end
    end
  end

  def self.get_reviewable_rating(reviewable_type, reviewable_id)
    cache_key = "#{CACHE_KEY_PREFIX}:reviewable:#{reviewable_type}:#{reviewable_id}"

    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      with_circuit_breaker('review_rating') do
        with_retry do
          reviews = Review.where(reviewable_type: reviewable_type, reviewable_id: reviewable_id)
          {
            average_rating: reviews.average(:rating) || 0,
            total_reviews: reviews.count,
            rating_distribution: reviews.group(:rating).count
          }
        end
      end
    end
  end

  def self.clear_rating_cache(reviewable_type, reviewable_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:update:#{reviewable_type}:#{reviewable_id}",
      "#{CACHE_KEY_PREFIX}:reviewable:#{reviewable_type}:#{reviewable_id}",
      "reviewable_rating:#{reviewable_type}:#{reviewable_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end