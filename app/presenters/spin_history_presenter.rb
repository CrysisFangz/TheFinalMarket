# frozen_string_literal: true

# Presenter for spin history
class SpinHistoryPresenter
  def initialize(spins)
    @spins = spins
  end

  def as_json
    @spins.map do |spin|
      {
        id: spin.id,
        prize_name: spin.spin_to_win_prize.prize_name,
        prize_value: spin.spin_to_win_prize.prize_value,
        prize_type: spin.spin_to_win_prize.prize_type,
        spun_at: spin.spun_at
      }
    end
  end
end