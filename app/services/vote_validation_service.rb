class VoteValidationService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'helpful_vote_validation'
  CACHE_TTL = 5.minutes

  def self.validate_vote_on_own_review(vote)
    cache_key = "#{CACHE_KEY_PREFIX}:own_review:#{vote.user_id}:#{vote.review_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('vote_validation') do
        with_retry do
          if vote.user_id == vote.review.user_id
            vote.errors.add(:base, "You cannot mark your own review as helpful")
            false
          else
            true
          end
        end
      end
    end
  end

  def self.validate_vote_uniqueness(vote)
    cache_key = "#{CACHE_KEY_PREFIX}:uniqueness:#{vote.user_id}:#{vote.review_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('vote_validation') do
        with_retry do
          existing_vote = HelpfulVote.where(user_id: vote.user_id, review_id: vote.review_id).exists?
          if existing_vote
            vote.errors.add(:base, "You have already voted on this review")
            false
          else
            true
          end
        end
      end
    end
  end

  def self.clear_validation_cache(user_id, review_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:own_review:#{user_id}:#{review_id}",
      "#{CACHE_KEY_PREFIX}:uniqueness:#{user_id}:#{review_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end