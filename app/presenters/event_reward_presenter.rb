class EventRewardPresenter
  def initialize(reward)
    @reward = reward
  end

  def as_json(options = {})
    {
      id: @reward.id,
      seasonal_event_id: @reward.seasonal_event_id,
      reward_name: @reward.reward_name,
      description: @reward.description,
      reward_type: @reward.reward_type,
      prize_type: @reward.prize_type,
      prize_value: @reward.prize_value,
      bonus_coins: @reward.bonus_coins,
      repeatable: @reward.repeatable?,
      max_claims: @reward.max_claims,
      created_at: @reward.created_at,
      updated_at: @reward.updated_at
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end