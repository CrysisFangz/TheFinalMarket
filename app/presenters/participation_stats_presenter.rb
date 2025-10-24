class ParticipationStatsPresenter
  def initialize(participation)
    @participation = participation
  end

  def stats
    {
      clues_found: participation.clues_found,
      total_clues: total_clues,
      progress: progress,
      incorrect_attempts: participation.incorrect_attempts,
      hints_used: participation.hints_used,
      time_elapsed: time_elapsed,
      completed: participation.completed?,
      rank: participation.rank
    }
  end

  private

  attr_reader :participation

  def total_clues
    participation.treasure_hunt.treasure_hunt_clues.count
  end

  def progress
    ProgressCalculator.new(participation).call
  end

  def time_elapsed
    return participation.time_taken_seconds if participation.completed?
    (Time.current - participation.started_at).to_i
  end
end