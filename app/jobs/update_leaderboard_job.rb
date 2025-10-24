class UpdateLeaderboardJob < ApplicationJob
  queue_as :low_priority

  def perform(event_id)
    event = SeasonalEvent.find(event_id)
    leaderboard_service = SeasonalEventLeaderboardService.new(event)
    leaderboard_service.leaderboard(limit: 1000) # Update a larger set for accuracy
  end
end