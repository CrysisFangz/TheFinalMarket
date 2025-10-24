class RewardCalculator
  def initialize(participation)
    @participation = participation
  end

  def call
    base_reward = calculate_base_reward
    speed_bonus = calculate_speed_bonus(base_reward)
    hint_penalty = calculate_hint_penalty(base_reward)

    total_reward = (base_reward + speed_bonus - hint_penalty).to_i

    ActiveRecord::Base.transaction do
      participation.user.increment!(:coins, total_reward)
      participation.user.increment!(:experience_points, total_reward / 2)
    end
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Error awarding rewards: #{e.message}")
    raise
  end

  private

  attr_reader :participation

  def calculate_base_reward
    case participation.treasure_hunt.difficulty.to_sym
    when :easy
      100
    when :medium
      250
    when :hard
      500
    when :expert
      1000
    end
  end

  def calculate_speed_bonus(base_reward)
    participation.rank <= 3 ? base_reward * 0.5 : 0
  end

  def calculate_hint_penalty(base_reward)
    participation.hints_used * (base_reward * 0.1)
  end
end