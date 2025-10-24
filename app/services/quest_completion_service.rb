# frozen_string_literal: true

# Service for completing quests and awarding rewards
class QuestCompletionService
  include ServiceResultHelper

  def initialize(quest, user)
    @quest = quest
    @user = user
  end

  def complete_quest
    participation = @quest.participation_for(@user)
    return failure('No participation found') unless participation

    participation.update!(
      completed: true,
      completed_at: Time.current
    )

    # Award rewards asynchronously
    QuestRewardService.new(@quest, @user).award_rewards

    # Send notification asynchronously
    QuestNotificationService.new(@quest, @user).notify_completion

    # Publish event
    EventSourcing::EventStore.append_event(
      @quest,
      'quest_completed',
      { user_id: @user.id, completed_at: participation.completed_at },
      { user_id: @user.id }
    )

    success(participation)
  rescue ActiveRecord::RecordInvalid => e
    failure("Failed to complete quest: #{e.message}")
  end
end