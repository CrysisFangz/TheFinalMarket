class DailyChallengePresenter
  attr_reader :challenge

  def initialize(challenge)
    @challenge = challenge
  end

  def as_json(options = {})
    {
      id: challenge.id,
      title: challenge.title,
      description: challenge.description,
      challenge_type: challenge.challenge_type,
      difficulty: challenge.difficulty,
      target_value: challenge.target_value,
      reward_points: challenge.reward_points,
      reward_coins: challenge.reward_coins,
      active_date: challenge.active_date,
      expires_at: challenge.expires_at,
      active: challenge.active
    }.merge(options)
  end

  def for_api
    as_json
  end
end