# frozen_string_literal: true

# Presenter for spin statistics
class SpinStatisticsPresenter
  def initialize(statistics)
    @statistics = statistics
  end

  def as_json
    @statistics
  end

  def formatted_total_spins
    @statistics[:total_spins].to_s
  end

  def formatted_unique_spinners
    @statistics[:unique_spinners].to_s
  end

  def formatted_total_value_awarded
    ActionController::Base.helpers.number_to_currency(@statistics[:total_value_awarded])
  end
end