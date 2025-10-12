class GamificationChannel < ApplicationCable::Channel
  def subscribed
    user = User.find_by(id: params[:user_id])
    return reject unless user
    
    stream_for user
  end

  def unsubscribed
    stop_all_streams
  end
  
  # Broadcast points awarded
  def self.broadcast_points_awarded(user, amount, reason)
    broadcast_to user, {
      type: 'points_awarded',
      amount: amount,
      reason: reason,
      new_total: user.points
    }
  end
  
  # Broadcast coins awarded
  def self.broadcast_coins_awarded(user, amount, reason)
    broadcast_to user, {
      type: 'coins_awarded',
      amount: amount,
      reason: reason,
      new_total: user.coins
    }
  end
  
  # Broadcast level up
  def self.broadcast_level_up(user, new_level)
    broadcast_to user, {
      type: 'level_up',
      new_level: new_level,
      rewards: level_rewards(new_level)
    }
  end
  
  # Broadcast achievement unlocked
  def self.broadcast_achievement_unlocked(user, achievement)
    broadcast_to user, {
      type: 'achievement_unlocked',
      achievement: {
        id: achievement.id,
        name: achievement.name,
        description: achievement.description,
        icon_url: achievement.icon_url,
        tier: achievement.tier,
        points: achievement.points
      }
    }
  end
  
  # Broadcast challenge completed
  def self.broadcast_challenge_completed(user, challenge)
    broadcast_to user, {
      type: 'challenge_completed',
      challenge: {
        id: challenge.id,
        title: challenge.title,
        reward_points: challenge.reward_points,
        reward_coins: challenge.reward_coins
      }
    }
  end
  
  private
  
  def self.level_rewards(level)
    {
      coins: level * 50,
      unlocks: []
    }
  end
end

