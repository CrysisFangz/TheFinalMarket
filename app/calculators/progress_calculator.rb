class ProgressCalculator
  def initialize(participation)
    @participation = participation
  end

  def call
    total_clues = participation.treasure_hunt.treasure_hunt_clues.count
    return 100.0 if total_clues.zero?

    ((participation.clues_found.to_f / total_clues) * 100).round(2)
  end

  private

  attr_reader :participation
end