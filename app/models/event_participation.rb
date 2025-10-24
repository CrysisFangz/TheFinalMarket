class EventParticipation < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :seasonal_event
  belongs_to :user

  validates :seasonal_event, presence: true
  validates :user, presence: true
  validates :user_id, uniqueness: { scope: :seasonal_event_id }

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Get completed challenges
  def completed_challenges
    ParticipationService.get_completed_challenges(self)
  end

  # Get available challenges
  def available_challenges
    ParticipationService.get_available_challenges(self)
  end

  # Get progress summary
  def progress_summary
    ParticipationService.calculate_progress_summary(self)
  end

  private

  def publish_created_event
    EventPublisher.publish('event_participation.created', {
      participation_id: id,
      seasonal_event_id: seasonal_event_id,
      user_id: user_id,
      joined_at: joined_at,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('event_participation.updated', {
      participation_id: id,
      seasonal_event_id: seasonal_event_id,
      user_id: user_id,
      points: points,
      rank: rank,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('event_participation.destroyed', {
      participation_id: id,
      seasonal_event_id: seasonal_event_id,
      user_id: user_id,
      points: points
    })
  end
end