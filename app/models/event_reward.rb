class EventReward < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :seasonal_event

  validates :seasonal_event, presence: true
  validates :reward_type, presence: true
  validates :reward_name, presence: true

  enum reward_type: {
    milestone: 0,
    leaderboard: 1,
    participation: 2,
    random_drop: 3
  }

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Award reward to user
  def award_to(user)
    with_retry do
      RewardDistributionService.award_to(self, user)
    end
  end

  private

  def publish_created_event
    EventPublisher.publish('event_reward.created', {
      reward_id: id,
      seasonal_event_id: seasonal_event_id,
      reward_name: reward_name,
      reward_type: reward_type,
      prize_type: prize_type,
      prize_value: prize_value,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('event_reward.updated', {
      reward_id: id,
      seasonal_event_id: seasonal_event_id,
      reward_name: reward_name,
      reward_type: reward_type,
      prize_type: prize_type,
      prize_value: prize_value,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('event_reward.destroyed', {
      reward_id: id,
      seasonal_event_id: seasonal_event_id,
      reward_name: reward_name,
      reward_type: reward_type
    })
  end
end