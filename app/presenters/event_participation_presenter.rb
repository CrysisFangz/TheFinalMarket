class EventParticipationPresenter
  def initialize(participation)
    @participation = participation
  end

  def as_json(options = {})
    {
      id: @participation.id,
      seasonal_event_id: @participation.seasonal_event_id,
      user_id: @participation.user_id,
      points: @participation.points,
      rank: @participation.rank,
      joined_at: @participation.joined_at,
      created_at: @participation.created_at,
      updated_at: @participation.updated_at,
      completed_challenges_count: @participation.completed_challenges.count,
      available_challenges_count: @participation.available_challenges.count,
      progress_summary: @participation.progress_summary
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end