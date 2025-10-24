module TreasureHunt
  class LeaderboardPresenter
    def initialize(leaderboard_data)
      @leaderboard_data = leaderboard_data
    end

    def present
      @leaderboard_data.map do |entry|
        {
          user_id: entry[:user].id,
          user_name: entry[:user].name, # Assuming User has name
          rank: entry[:rank],
          time_taken: entry[:time_taken],
          clues_found: entry[:clues_found],
          completed_at: entry[:completed_at],
          prize: entry[:prize]
        }
      end
    end

    private

    attr_reader :leaderboard_data
  end
end