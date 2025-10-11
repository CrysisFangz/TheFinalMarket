class ShoppingQuest < ApplicationRecord
  has_many :quest_objectives, dependent: :destroy
  has_many :quest_participations, dependent: :destroy
  has_many :participants, through: :quest_participations, source: :user
  
  validates :name, presence: true
  validates :quest_type, presence: true
  validates :status, presence: true
  
  enum quest_type: {
    daily: 0,
    weekly: 1,
    monthly: 2,
    seasonal: 3,
    special_event: 4,
    story_quest: 5
  }
  
  enum status: {
    draft: 0,
    active: 1,
    completed: 2,
    expired: 3
  }
  
  enum difficulty: {
    beginner: 0,
    intermediate: 1,
    advanced: 2,
    expert: 3
  }
  
  # Scopes
  scope :active_quests, -> { where(status: :active).where('starts_at <= ? AND ends_at >= ?', Time.current, Time.current) }
  scope :by_type, ->(type) { where(quest_type: type) }
  scope :by_difficulty, ->(difficulty) { where(difficulty: difficulty) }
  
  # Check if user can start quest
  def can_start?(user)
    active? &&
    starts_at <= Time.current &&
    ends_at >= Time.current &&
    !participants.include?(user) &&
    meets_requirements?(user)
  end
  
  # Start quest for user
  def start_for(user)
    return false unless can_start?(user)
    
    participation = quest_participations.create!(
      user: user,
      started_at: Time.current,
      progress: 0
    )
    
    participation
  end
  
  # Get user's participation
  def participation_for(user)
    quest_participations.find_by(user: user)
  end
  
  # Check quest progress for user
  def check_progress(user)
    participation = participation_for(user)
    return nil unless participation
    
    total_objectives = quest_objectives.count
    completed_objectives = 0
    
    quest_objectives.each do |objective|
      if objective.completed_by?(user)
        completed_objectives += 1
      end
    end
    
    progress = (completed_objectives.to_f / total_objectives * 100).round(2)
    participation.update!(progress: progress)
    
    # Check if quest is complete
    if progress >= 100 && !participation.completed?
      complete_quest_for(user)
    end
    
    {
      progress: progress,
      completed_objectives: completed_objectives,
      total_objectives: total_objectives,
      completed: participation.completed?
    }
  end
  
  # Complete quest for user
  def complete_quest_for(user)
    participation = participation_for(user)
    return unless participation
    
    participation.update!(
      completed: true,
      completed_at: Time.current
    )
    
    # Award rewards
    award_rewards(user)
    
    # Send notification
    notify_completion(user)
  end
  
  # Get leaderboard
  def leaderboard(limit: 10)
    quest_participations
      .where(completed: true)
      .order(completed_at: :asc)
      .limit(limit)
      .includes(:user)
      .map.with_index(1) do |participation, index|
        {
          rank: index,
          user: participation.user,
          completed_at: participation.completed_at,
          time_taken: (participation.completed_at - participation.started_at).to_i
        }
      end
  end
  
  # Get statistics
  def statistics
    {
      total_participants: participants.count,
      completed_count: quest_participations.where(completed: true).count,
      completion_rate: completion_rate,
      average_progress: quest_participations.average(:progress).to_f.round(2),
      difficulty: difficulty,
      quest_type: quest_type
    }
  end
  
  private
  
  def meets_requirements?(user)
    return true if required_level.nil?
    user.level >= required_level
  end
  
  def award_rewards(user)
    # Award coins
    user.increment!(:coins, reward_coins) if reward_coins > 0
    
    # Award experience points
    user.increment!(:experience_points, reward_experience) if reward_experience > 0
    
    # Award loyalty tokens
    if reward_tokens > 0
      user.loyalty_token&.earn(reward_tokens, 'quest_completion')
    end
    
    # Award items/products
    award_items(user) if reward_items.present?
    
    # Unlock achievements
    unlock_achievements(user) if unlocks_achievement_id.present?
  end
  
  def award_items(user)
    # Implementation depends on your item/product system
  end
  
  def unlock_achievements(user)
    achievement = Achievement.find_by(id: unlocks_achievement_id)
    achievement&.award_to(user)
  end
  
  def notify_completion(user)
    Notification.create!(
      recipient: user,
      notifiable: self,
      notification_type: 'quest_completed',
      title: "Quest Completed: #{name}!",
      message: description,
      data: {
        coins: reward_coins,
        experience: reward_experience,
        tokens: reward_tokens
      }
    )
  end
  
  def completion_rate
    return 0 if participants.count.zero?
    
    completed = quest_participations.where(completed: true).count
    ((completed.to_f / participants.count) * 100).round(2)
  end
end

