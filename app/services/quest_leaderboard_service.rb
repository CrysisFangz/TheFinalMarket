# frozen_string_literal: true

# Service for quest leaderboard
class QuestLeaderboardService
  include ServiceResultHelper

  def initialize(quest, limit: 10)
    @quest = quest
    @limit = limit
  end

  def leaderboard
    participations = @quest.quest_participations
                           .where(completed: true)
                           .order(completed_at: :asc)
                           .limit(@limit)
                           .includes(:user)

    leaderboard_data = participations.map.with_index(1) do |participation, index|
      {
        rank: index,
        user: participation.user,
        completed_at: participation.completed_at,
        time_taken: (participation.completed_at - participation.started_at).to_i
      }
    end

    success(leaderboard_data)
  end
end