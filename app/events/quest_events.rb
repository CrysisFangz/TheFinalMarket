# frozen_string_literal: true

# Quest lifecycle events
class QuestStartedEvent < EventSourcing::Event
  def initialize(quest, user, started_data = {})
    super(
      entity: quest,
      event_type: 'quest_started',
      data: started_data.merge(user_id: user.id),
      metadata: { user_id: user.id }
    )
  end

  def apply_to(quest)
    # No state change needed for quest itself
  end
end

class QuestProgressUpdatedEvent < EventSourcing::Event
  def initialize(quest, user, progress_data = {})
    super(
      entity: quest,
      event_type: 'quest_progress_updated',
      data: progress_data.merge(user_id: user.id),
      metadata: { user_id: user.id }
    )
  end

  def apply_to(quest)
    # Update participation progress if needed
  end
end

class QuestCompletedEvent < EventSourcing::Event
  def initialize(quest, user, completion_data = {})
    super(
      entity: quest,
      event_type: 'quest_completed',
      data: completion_data.merge(user_id: user.id),
      metadata: { user_id: user.id }
    )
  end

  def apply_to(quest)
    # No state change needed for quest itself
  end
end

class QuestRewardsAwardedEvent < EventSourcing::Event
  def initialize(quest, user, reward_data = {})
    super(
      entity: quest,
      event_type: 'quest_rewards_awarded',
      data: reward_data.merge(user_id: user.id),
      metadata: { user_id: user.id }
    )
  end

  def apply_to(quest)
    # No state change needed for quest itself
  end
end

class QuestNotificationSentEvent < EventSourcing::Event
  def initialize(quest, user, notification_data = {})
    super(
      entity: quest,
      event_type: 'quest_notification_sent',
      data: notification_data.merge(user_id: user.id),
      metadata: { user_id: user.id }
    )
  end

  def apply_to(quest)
    # No state change needed for quest itself
  end
end