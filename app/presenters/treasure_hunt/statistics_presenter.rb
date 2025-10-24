module TreasureHunt
  class StatisticsPresenter
    def initialize(statistics_data)
      @statistics_data = statistics_data
    end

    def present
      {
        total_participants: @statistics_data[:total_participants],
        completed_count: @statistics_data[:completed_count],
        average_time: @statistics_data[:average_time],
        fastest_time: @statistics_data[:fastest_time],
        completion_rate: @statistics_data[:completion_rate],
        difficulty: @statistics_data[:difficulty],
        total_clues: @statistics_data[:total_clues]
      }
    end

    private

    attr_reader :statistics_data
  end
end