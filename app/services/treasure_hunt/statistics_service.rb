module TreasureHunt
  class StatisticsService
    def initialize(treasure_hunt)
      @treasure_hunt = treasure_hunt
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        stats = @treasure_hunt.treasure_hunt_participations
          .where(completed: true)
          .select(
            'COUNT(*) as completed_count',
            'AVG(time_taken_seconds) as average_time',
            'MIN(time_taken_seconds) as fastest_time'
          )
          .first

        total_participants = @treasure_hunt.participants.count
        completed_count = stats.completed_count || 0
        average_time = (stats.average_time || 0).to_f.round(2)
        fastest_time = stats.fastest_time

        completion_rate = total_participants.zero? ? 0 : ((completed_count.to_f / total_participants) * 100).round(2)

        {
          total_participants: total_participants,
          completed_count: completed_count,
          average_time: average_time,
          fastest_time: fastest_time,
          completion_rate: completion_rate,
          difficulty: @treasure_hunt.difficulty,
          total_clues: @treasure_hunt.treasure_hunt_clues.count
        }
      end
    end

    private

    def cache_key
      "treasure_hunt:#{@treasure_hunt.id}:statistics:#{@treasure_hunt.updated_at.to_i}"
    end

    attr_reader :treasure_hunt
  end
end