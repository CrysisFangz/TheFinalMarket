class AwardPrizesJob < ApplicationJob
  queue_as :default

  def perform(treasure_hunt_id)
    treasure_hunt = TreasureHunt.find(treasure_hunt_id)
    leaderboard_service = TreasureHunt::LeaderboardService.new(treasure_hunt, limit: 3)
    leaderboard = leaderboard_service.call

    leaderboard.each do |entry|
      next if entry[:prize].zero?

      ActiveRecord::Base.transaction do
        entry[:user].increment!(:coins, entry[:prize])

        Notification.create!(
          recipient: entry[:user],
          notifiable: treasure_hunt,
          notification_type: 'treasure_hunt_prize',
          title: "Treasure Hunt Prize!",
          message: "You won #{entry[:prize]} coins for finishing #{entry[:rank].ordinalize}!",
          data: { rank: entry[:rank], prize: entry[:prize] }
        )
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Treasure hunt not found: #{e.message}")
  rescue => e
    Rails.logger.error("Error awarding prizes: #{e.message}")
    # Optionally, retry or notify admins
  end
end