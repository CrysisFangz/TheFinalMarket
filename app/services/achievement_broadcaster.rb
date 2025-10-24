class AchievementBroadcaster
  def self.call(user_achievement)
    new(user_achievement).broadcast
  end

  def initialize(user_achievement)
    @user_achievement = user_achievement
  end

  def broadcast
    broadcast_to_feed
    broadcast_celebration
  rescue => e
    # Log error and handle gracefully for resilience
    Rails.logger.error("Failed to broadcast achievement: #{e.message}")
    # Optionally, enqueue for retry or send to dead letter queue
  end

  private

  def broadcast_to_feed
    @user_achievement.broadcast_replace_to(
      "user_#{@user_achievement.user_id}_achievements",
      target: "achievement_#{@user_achievement.id}",
      partial: "achievements/achievement_card",
      locals: { user_achievement: @user_achievement }
    )
  end

  def broadcast_celebration
    @user_achievement.broadcast_append_to(
      "user_#{@user_achievement.user_id}_notifications",
      target: "achievement_notifications",
      partial: "achievements/celebration",
      locals: { achievement: @user_achievement.achievement }
    )
  end
end