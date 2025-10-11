class SeasonalEvent < ApplicationRecord
  has_many :event_challenges, dependent: :destroy
  has_many :event_participations, dependent: :destroy
  has_many :participants, through: :event_participations, source: :user
  has_many :event_rewards, dependent: :destroy
  
  validates :name, presence: true
  validates :event_type, presence: true
  validates :status, presence: true
  
  enum event_type: {
    holiday: 0,
    seasonal: 1,
    anniversary: 2,
    flash_sale: 3,
    community: 4,
    special: 5
  }
  
  enum status: {
    upcoming: 0,
    active: 1,
    ended: 2
  }
  
  # Scopes
  scope :active_events, -> { where(status: :active).where('starts_at <= ? AND ends_at >= ?', Time.current, Time.current) }
  scope :upcoming_events, -> { where(status: :upcoming).where('starts_at > ?', Time.current) }
  scope :by_type, ->(type) { where(event_type: type) }
  
  # Start the event
  def start!
    update!(status: :active, started_at: Time.current)
    notify_all_users
  end
  
  # End the event
  def end!
    update!(status: :ended, ended_at: Time.current)
    award_final_prizes
  end
  
  # Join event
  def join(user)
    return false unless active?
    return false if participants.include?(user)
    
    participation = event_participations.create!(
      user: user,
      joined_at: Time.current,
      points: 0,
      rank: 0
    )
    
    participation
  end
  
  # Get user's participation
  def participation_for(user)
    event_participations.find_by(user: user)
  end
  
  # Award points to user
  def award_points(user, points, reason = nil)
    participation = participation_for(user)
    return unless participation
    
    participation.increment!(:points, points)
    update_leaderboard
    
    # Check for milestone rewards
    check_milestone_rewards(user, participation.points)
  end
  
  # Get leaderboard
  def leaderboard(limit: 100)
    event_participations
      .order(points: :desc, joined_at: :asc)
      .limit(limit)
      .includes(:user)
      .map.with_index(1) do |participation, index|
        participation.update!(rank: index) if participation.rank != index
        {
          rank: index,
          user: participation.user,
          points: participation.points,
          joined_at: participation.joined_at
        }
      end
  end
  
  # Get user's rank
  def user_rank(user)
    participation = participation_for(user)
    return nil unless participation
    
    event_participations.where('points > ?', participation.points).count + 1
  end
  
  # Get statistics
  def statistics
    {
      total_participants: participants.count,
      total_points_awarded: event_participations.sum(:points),
      average_points: event_participations.average(:points).to_f.round(2),
      top_score: event_participations.maximum(:points),
      challenges_completed: event_challenges.sum(:completion_count),
      event_type: event_type,
      days_remaining: days_remaining
    }
  end
  
  # Get active challenges
  def active_challenges
    event_challenges.where(active: true)
  end
  
  # Check if event is currently active
  def currently_active?
    active? && starts_at <= Time.current && ends_at >= Time.current
  end
  
  # Days remaining
  def days_remaining
    return 0 unless currently_active?
    ((ends_at - Time.current) / 1.day).ceil
  end
  
  private
  
  def update_leaderboard
    # Recalculate ranks
    event_participations.order(points: :desc, joined_at: :asc).each.with_index(1) do |participation, index|
      participation.update_column(:rank, index)
    end
  end
  
  def check_milestone_rewards(user, points)
    event_rewards.where(reward_type: :milestone)
                 .where('threshold <= ?', points)
                 .where.not(id: user.claimed_event_rewards.select(:event_reward_id))
                 .each do |reward|
      reward.award_to(user)
    end
  end
  
  def award_final_prizes
    # Award prizes to top performers
    leaderboard(limit: 10).each do |entry|
      reward = event_rewards.find_by(reward_type: :leaderboard, rank: entry[:rank])
      reward&.award_to(entry[:user])
    end
  end
  
  def notify_all_users
    # Send notification to all users about event start
    User.find_each do |user|
      Notification.create!(
        recipient: user,
        notifiable: self,
        notification_type: 'seasonal_event_started',
        title: "#{name} Has Started!",
        message: description,
        data: { event_type: event_type, ends_at: ends_at }
      )
    end
  end
end

