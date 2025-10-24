# frozen_string_literal: true

# Service for managing quest participation
class QuestParticipationService
  include ServiceResultHelper

  def initialize(quest, user)
    @quest = quest
    @user = user
  end

  def start_quest
    return failure('Quest cannot be started') unless @quest.can_start?(@user)

    participation = @quest.quest_participations.create!(
      user: @user,
      started_at: Time.current,
      progress: 0
    )

    # Publish event
    EventSourcing::EventStore.append_event(
      @quest,
      'quest_started',
      { user_id: @user.id, started_at: participation.started_at },
      { user_id: @user.id }
    )

    success(participation)
  rescue ActiveRecord::RecordInvalid => e
    failure("Failed to start quest: #{e.message}")
  end

  def participation_for_user
    @quest.quest_participations.find_by(user: @user)
  end

  def can_start?
    @quest.can_start?(@user)
  end
end