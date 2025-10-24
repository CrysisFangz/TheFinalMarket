class RankCalculator
  def initialize(participation)
    @participation = participation
  end

  def call
    return 1 unless participation.completed_at

    # Optimized query to count participations completed before this one
    participation.treasure_hunt.treasure_hunt_participations
                 .where(completed: true)
                 .where('completed_at < ?', participation.completed_at)
                 .count + 1
  end

  private

  attr_reader :participation
end