# frozen_string_literal: true

# Service for quest statistics
class QuestStatisticsService
  include ServiceResultHelper

  def initialize(quest)
    @quest = quest
  end

  def statistics
    total_participants = @quest.participants.count
    completed_count = @quest.quest_participations.where(completed: true).count
    completion_rate = total_participants.zero? ? 0 : ((completed_count.to_f / total_participants) * 100).round(2)
    average_progress = @quest.quest_participations.average(:progress).to_f.round(2)

    stats = {
      total_participants: total_participants,
      completed_count: completed_count,
      completion_rate: completion_rate,
      average_progress: average_progress,
      difficulty: @quest.difficulty,
      quest_type: @quest.quest_type
    }

    success(stats)
  end
end