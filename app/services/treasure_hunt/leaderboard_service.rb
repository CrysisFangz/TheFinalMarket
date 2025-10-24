module TreasureHunt
  class LeaderboardService
    def initialize(treasure_hunt, limit: 10)
      @treasure_hunt = treasure_hunt
      @limit = limit
      @prize_calculator = PrizeCalculator.new(@treasure_hunt.prize_pool)
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        participations = @treasure_hunt.treasure_hunt_participations
          .where(completed: true)
          .order(completed_at: :asc, time_taken_seconds: :asc)
          .limit(@limit)
          .includes(:user)

        participations.map.with_index(1) do |participation, index|
          {
            user: participation.user,
            rank: index,
            time_taken: participation.time_taken_seconds,
            clues_found: participation.clues_found,
            completed_at: participation.completed_at,
            prize: @prize_calculator.calculate(index)
          }
        end
      end
    end

    private

    def cache_key
      "treasure_hunt:#{@treasure_hunt.id}:leaderboard:#{@limit}:#{@treasure_hunt.updated_at.to_i}"
    end

    attr_reader :treasure_hunt, :limit, :prize_calculator
  end
end