class HelpfulVote < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :user
  belongs_to :review

  validates :user_id, uniqueness: { scope: :review_id }
  validate :cannot_vote_on_own_review, :validate_vote_uniqueness

  # Caching
  after_create :clear_validation_cache
  after_update :clear_validation_cache
  after_destroy :clear_validation_cache

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  def self.cached_find(id)
    Rails.cache.fetch("helpful_vote:#{id}", expires_in: 30.minutes) do
      find_by(id: id)
    end
  end

  def self.cached_count_for_review(review_id)
    Rails.cache.fetch("helpful_vote_count:review:#{review_id}", expires_in: 10.minutes) do
      where(review_id: review_id).count
    end
  end

  def self.cached_helpful_count_for_review(review_id)
    Rails.cache.fetch("helpful_vote_helpful_count:review:#{review_id}", expires_in: 10.minutes) do
      where(review_id: review_id, helpful: true).count
    end
  end

  def presenter
    @presenter ||= HelpfulVotePresenter.new(self)
  end

  private

  def cannot_vote_on_own_review
    VoteValidationService.validate_vote_on_own_review(self)
  end

  def validate_vote_uniqueness
    VoteValidationService.validate_vote_uniqueness(self)
  end

  def clear_validation_cache
    VoteValidationService.clear_validation_cache(user_id, review_id)
    # Clear related caches
    Rails.cache.delete("helpful_vote_count:review:#{review_id}")
    Rails.cache.delete("helpful_vote_helpful_count:review:#{review_id}")
    Rails.cache.delete("helpful_vote:#{id}")
  end

  def publish_created_event
    EventPublisher.publish('helpful_vote.created', {
      vote_id: id,
      user_id: user_id,
      review_id: review_id,
      helpful: helpful?,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('helpful_vote.updated', {
      vote_id: id,
      user_id: user_id,
      review_id: review_id,
      helpful: helpful?,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('helpful_vote.destroyed', {
      vote_id: id,
      user_id: user_id,
      review_id: review_id,
      helpful: helpful?
    })
  end
end