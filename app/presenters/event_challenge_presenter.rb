class EventChallengePresenter
  def initialize(challenge)
    @challenge = challenge
  end

  def as_json(options = {})
    {
      id: @challenge.id,
      seasonal_event_id: @challenge.seasonal_event_id,
      name: @challenge.name,
      description: @challenge.description,
      challenge_type: @challenge.challenge_type,
      points_reward: @challenge.points_reward,
      bonus_coins: @challenge.bonus_coins,
      repeatable: @challenge.repeatable?,
      completion_count: @challenge.completion_count,
      created_at: @challenge.created_at,
      updated_at: @challenge.updated_at,
      progress: @challenge.progress_for(options[:current_user]),
      completed: @challenge.completed_by?(options[:current_user])
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end