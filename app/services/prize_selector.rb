# frozen_string_literal: true

# Service for selecting prizes based on probability
class PrizeSelector
  def initialize(spin_to_win)
    @spin_to_win = spin_to_win
  end

  def select_prize
    prizes = active_prizes
    return nil if prizes.empty?

    total_probability = prizes.sum(:probability)
    random = rand(0.0..total_probability)

    cumulative = 0.0
    prizes.each do |prize|
      cumulative += prize.probability
      return prize if random <= cumulative
    end

    # Fallback to first prize
    prizes.first
  rescue => e
    Rails.logger.error("Prize selection failed: #{e.message}", spin_to_win_id: @spin_to_win.id)
    nil
  end

  private

  def active_prizes
    @spin_to_win.spin_to_win_prizes.where(active: true)
  end
end