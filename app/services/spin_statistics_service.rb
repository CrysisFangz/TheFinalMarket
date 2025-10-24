# frozen_string_literal: true

# Service for calculating spin statistics
class SpinStatisticsService
  def initialize(spin_to_win)
    @spin_to_win = spin_to_win
  end

  def statistics
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      {
        total_spins: total_spins,
        unique_spinners: unique_spinners,
        prizes_awarded: prizes_awarded,
        most_common_prize: most_common_prize,
        total_value_awarded: total_value_awarded
      }
    end
  end

  def prize_distribution
    Rails.cache.fetch(prize_distribution_cache_key, expires_in: 1.hour) do
      @spin_to_win.spin_to_win_prizes.map do |prize|
        {
          prize_name: prize.prize_name,
          probability: prize.probability,
          times_won: times_won_for_prize(prize),
          value: prize.prize_value
        }
      end
    end
  end

  private

  def total_spins
    @spin_to_win.spin_to_win_spins.count
  end

  def unique_spinners
    @spin_to_win.spin_to_win_spins.distinct.count(:user_id)
  end

  def prizes_awarded
    total_spins
  end

  def most_common_prize
    result = @spin_to_win.spin_to_win_spins.group(:spin_to_win_prize_id)
                                          .count
                                          .max_by { |_, count| count }
    return nil unless result

    prize_id = result.first
    SpinToWinPrize.find(prize_id).prize_name
  end

  def total_value_awarded
    @spin_to_win.spin_to_win_spins.joins(:spin_to_win_prize)
                                  .where(spin_to_win_prizes: { prize_type: [:coins, :experience_points] })
                                  .sum('spin_to_win_prizes.prize_value')
  end

  def times_won_for_prize(prize)
    prize.times_won
  end

  def cache_key
    "spin_to_win_statistics_#{@spin_to_win.id}_#{@spin_to_win.updated_at.to_i}"
  end

  def prize_distribution_cache_key
    "spin_to_win_prize_distribution_#{@spin_to_win.id}_#{@spin_to_win.updated_at.to_i}"
  end
end