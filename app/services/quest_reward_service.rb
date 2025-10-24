# frozen_string_literal: true

# Service for awarding quest rewards with resilience
class QuestRewardService
  include ServiceResultHelper
  include CircuitBreaker

  def initialize(quest, user)
    @quest = quest
    @user = user
  end

  def award_rewards
    CircuitBreaker.with_circuit_breaker(name: 'quest_rewards') do
      # Award coins
      @user.increment!(:coins, @quest.reward_coins) if @quest.reward_coins > 0

      # Award experience points
      @user.increment!(:experience_points, @quest.reward_experience) if @quest.reward_experience > 0

      # Award loyalty tokens
      if @quest.reward_tokens > 0
        @user.loyalty_token&.earn(@quest.reward_tokens, 'quest_completion')
      end

      # Award items/products
      award_items if @quest.reward_items.present?

      # Unlock achievements
      unlock_achievements if @quest.unlocks_achievement_id.present?

      # Publish event
      EventSourcing::EventStore.append_event(
        @quest,
        'rewards_awarded',
        {
          user_id: @user.id,
          coins: @quest.reward_coins,
          experience: @quest.reward_experience,
          tokens: @quest.reward_tokens
        },
        { user_id: @user.id }
      )

      success(true)
    end
  rescue => e
    Rails.logger.error("Quest reward failure: #{e.message}", quest_id: @quest.id, user_id: @user.id)
    failure("Failed to award rewards: #{e.message}")
  end

  private

  def award_items
    # Implementation depends on your item/product system
    # For now, placeholder
  end

  def unlock_achievements
    achievement = Achievement.find_by(id: @quest.unlocks_achievement_id)
    achievement&.award_to(@user)
  end
end