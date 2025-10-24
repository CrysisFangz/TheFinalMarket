class HelpfulVotePresenter
  include CircuitBreaker
  include Retryable

  def initialize(vote)
    @vote = vote
  end

  def as_json(options = {})
    cache_key = "helpful_vote_presenter:#{@vote.id}:#{@vote.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      with_circuit_breaker('vote_presenter') do
        with_retry do
          {
            id: @vote.id,
            user_id: @vote.user_id,
            review_id: @vote.review_id,
            helpful: @vote.helpful?,
            created_at: @vote.created_at,
            updated_at: @vote.updated_at,
            user: user_data,
            review: review_data
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

  private

  def user_data
    Rails.cache.fetch("user_data:#{@vote.user_id}", expires_in: 30.minutes) do
      with_circuit_breaker('user_data') do
        with_retry do
          {
            id: @vote.user.id,
            username: @vote.user.username,
            reputation_score: @vote.user.reputation_score
          }
        end
      end
    end
  end

  def review_data
    Rails.cache.fetch("review_data:#{@vote.review_id}", expires_in: 15.minutes) do
      with_circuit_breaker('review_data') do
        with_retry do
          {
            id: @vote.review.id,
            rating: @vote.review.rating,
            comment: @vote.review.comment,
            product_id: @vote.review.product_id
          }
        end
      end
    end
  end
end