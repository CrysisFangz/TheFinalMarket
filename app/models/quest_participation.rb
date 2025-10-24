# frozen_string_literal: true

# QuestParticipation model refactored for performance and resilience.
# Participation logic extracted into dedicated service for optimization.
class QuestParticipation < ApplicationRecord
  belongs_to :shopping_quest
  belongs_to :user

  # Enhanced validations with custom messages
  validates :shopping_quest, presence: true
  validates :user, presence: true
  validates :user_id, uniqueness: { scope: :shopping_quest_id, message: "already participating in this quest" }
  validates :joined_at, presence: true

  # Enhanced scopes with performance optimization
  scope :active, -> { joins(:shopping_quest).where('shopping_quests.ends_at > ?', Time.current) }
  scope :completed, -> { joins(:shopping_quest).where('shopping_quests.ends_at <= ?', Time.current) }
  scope :with_quest, -> { includes(:shopping_quest) }
  scope :with_user, -> { includes(:user) }

  # Event-driven: Publish events on participation lifecycle
  after_create :publish_participation_joined_event
  after_update :publish_completion_event, if: :saved_change_to_completed_at?

  # Get objectives progress using service
  def objectives_progress
    QuestParticipationService.get_objectives_progress(self)
  end

  # Check if all objectives are complete using service
  def all_objectives_complete?
    QuestParticipationService.all_objectives_complete?(self)
  end

  # Get completion percentage using service
  def completion_percentage
    QuestParticipationService.calculate_completion_percentage(self)
  end

  private

  def publish_participation_joined_event
    Rails.logger.info("Quest participation joined: ID=#{id}, User=#{user_id}, Quest=#{shopping_quest_id}")
    # In a full event system: EventPublisher.publish('quest_participation_joined', self.attributes)
  end

  def publish_completion_event
    Rails.logger.info("Quest participation completed: ID=#{id}, User=#{user_id}")
    # In a full event system: EventPublisher.publish('quest_participation_completed', self.attributes)
  end
end

