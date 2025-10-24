module TreasureHunt
  class PrizeCalculator
    def initialize(prize_pool)
      @prize_pool = prize_pool
    end

    def calculate(rank)
      return 0 unless @prize_pool > 0

      case rank
      when 1
        (@prize_pool * 0.5).to_i
      when 2
        (@prize_pool * 0.3).to_i
      when 3
        (@prize_pool * 0.2).to_i
      else
        0
      end
    end

    private

    attr_reader :prize_pool
  end
end