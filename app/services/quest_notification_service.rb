# frozen_string_literal: true

# Service for quest notifications with resilience
class QuestNotificationService
  include ServiceResultHelper
  include CircuitBreaker

  def initialize(quest, user)
    @quest = quest
    @user = user
  end

  def notify_completion
    CircuitBreaker.with_circuit_breaker(name: 'quest_notifications') do
      Notification.create!(
        recipient: @user,
        notifiable: @quest,
        notification_type: 'quest_completed',
        title: "Quest Completed: #{@quest.name}!",
        message: @quest.description,
        data: {
          coins: @quest.reward_coins,
          experience: @quest.reward_experience,
          tokens: @quest.reward_tokens
        }
      )

      # Publish event
      EventSourcing::EventStore.append_event(
        @quest,
        'notification_sent',
        { user_id: @user.id, notification_type: 'quest_completed' },
        { user_id: @user.id }
      )

      success(true)
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Quest notification failure: #{e.message}", quest_id: @quest.id, user_id: @user.id)
    failure("Failed to send notification: #{e.message}")
  end
end