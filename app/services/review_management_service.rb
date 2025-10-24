class ReviewManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'review_management'
  CACHE_TTL = 10.minutes

  def self.mark_helpful(review, user)
    cache_key = "#{CACHE_KEY_PREFIX}:helpful:#{review.id}:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_management') do
        with_retry do
          # Check if user already voted
          existing_vote = review.helpful_votes.find_by(user: user)
          if existing_vote
            raise ArgumentError, "User has already voted on this review"
          end

          # Create vote
          vote = review.helpful_votes.create!(user: user)
          review.increment!(:helpful_count)

          EventPublisher.publish('review.helpful_vote_added', {
            review_id: review.id,
            user_id: user.id,
            reviewer_id: review.reviewer_id,
            reviewable_type: review.reviewable_type,
            reviewable_id: review.reviewable_id,
            helpful_count: review.helpful_count
          })

          vote
        end
      end
    end
  end

  def self.mark_unhelpful(review, user)
    cache_key = "#{CACHE_KEY_PREFIX}:unhelpful:#{review.id}:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_management') do
        with_retry do
          # Find and destroy existing vote
          vote = review.helpful_votes.find_by(user: user)
          if vote
            vote.destroy
            review.decrement!(:helpful_count)

            EventPublisher.publish('review.helpful_vote_removed', {
              review_id: review.id,
              user_id: user.id,
              reviewer_id: review.reviewer_id,
              reviewable_type: review.reviewable_type,
              reviewable_id: review.reviewable_id,
              helpful_count: review.helpful_count
            })
          end

          vote
        end
      end
    end
  end

  def self.get_helpful_votes(review_id)
    cache_key = "#{CACHE_KEY_PREFIX}:helpful_votes:#{review_id}"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      with_circuit_breaker('review_management') do
        with_retry do
          Review.find(review_id).helpful_votes.includes(:user).map do |vote|
            {
              id: vote.id,
              user_id: vote.user_id,
              username: vote.user.username,
              created_at: vote.created_at
            }
          end
        end
      end
    end
  end

  def self.clear_review_cache(review_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:helpful:#{review_id}",
      "#{CACHE_KEY_PREFIX}:unhelpful:#{review_id}",
      "#{CACHE_KEY_PREFIX}:helpful_votes:#{review_id}",
      "review:#{review_id}",
      "review_helpful_count:#{review_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end