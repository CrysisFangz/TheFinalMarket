class EventChallenge < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :seasonal_event
  has_many :challenge_completions, dependent: :destroy

  validates :seasonal_event, presence: true
  validates :name, presence: true
  validates :challenge_type, presence: true
  validates :points_reward, numericality: { greater_than: 0 }

  enum challenge_type: {
    purchase: 0,
    social: 1,
    engagement: 2,
    collection: 3,
    time_limited: 4
  }

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Check if user completed this challenge
  def completed_by?(user)
    Rails.cache.fetch("challenge:#{id}:completed_by:#{user.id}", expires_in: 5.minutes) do
      challenge_completions.exists?(user: user)
    end
  end

  # Complete challenge for user
  def complete_for(user)
    with_retry do
      ChallengeCompletionService.complete_for(self, user)
    end
  end

  # Get progress for user
  def progress_for(user)
    ChallengeProgressService.calculate_progress(self, user)
  end

  private

  def publish_created_event
    EventPublisher.publish('event_challenge.created', {
      challenge_id: id,
      seasonal_event_id: seasonal_event_id,
      name: name,
      challenge_type: challenge_type,
      points_reward: points_reward,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('event_challenge.updated', {
      challenge_id: id,
      seasonal_event_id: seasonal_event_id,
      name: name,
      challenge_type: challenge_type,
      points_reward: points_reward,
      completion_count: completion_count,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('event_challenge.destroyed', {
      challenge_id: id,
      seasonal_event_id: seasonal_event_id,
      name: name,
      challenge_type: challenge_type
    })
  end
end