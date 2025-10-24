class AwardFinalPrizesJob < ApplicationJob
  queue_as :default

  def perform(event_id)
    event = SeasonalEvent.find(event_id)
    leaderboard = SeasonalEventLeaderboardService.new(event).leaderboard(limit: 10)
    leaderboard.each do |entry|
      reward = event.event_rewards.find_by(reward_type: :leaderboard, rank: entry[:rank])
      reward&.award_to(entry[:user])
    end
  end
end