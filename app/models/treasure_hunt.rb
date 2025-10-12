class TreasureHunt < ApplicationRecord
  has_many :treasure_hunt_clues, dependent: :destroy
  has_many :treasure_hunt_participations, dependent: :destroy
  has_many :participants, through: :treasure_hunt_participations, source: :user
  
  validates :name, presence: true
  validates :status, presence: true
  validates :difficulty, presence: true
  
  enum status: {
    draft: 0,
    active: 1,
    completed: 2,
    expired: 3
  }
  
  enum difficulty: {
    easy: 0,
    medium: 1,
    hard: 2,
    expert: 3
  }
  
  # Scopes
  scope :active_hunts, -> { where(status: :active).where('starts_at <= ? AND ends_at >= ?', Time.current, Time.current) }
  scope :upcoming, -> { where(status: :active).where('starts_at > ?', Time.current) }
  scope :by_difficulty, ->(difficulty) { where(difficulty: difficulty) }
  
  # Start the treasure hunt
  def start!
    update!(status: :active, started_at: Time.current)
  end
  
  # Complete the treasure hunt
  def complete!
    update!(status: :completed, completed_at: Time.current)
    award_prizes_to_winners
  end
  
  # Check if user can participate
  def can_participate?(user)
    active? && 
    starts_at <= Time.current && 
    ends_at >= Time.current &&
    !participants.include?(user) &&
    (max_participants.nil? || participants.count < max_participants)
  end
  
  # Join treasure hunt
  def join(user)
    return false unless can_participate?(user)
    
    participation = treasure_hunt_participations.create!(
      user: user,
      started_at: Time.current,
      clues_found: 0,
      current_clue_index: 0
    )
    
    participation
  end
  
  # Get user's participation
  def participation_for(user)
    treasure_hunt_participations.find_by(user: user)
  end
  
  # Check if user completed the hunt
  def completed_by?(user)
    participation = participation_for(user)
    participation&.completed?
  end
  
  # Get leaderboard
  def leaderboard(limit: 10)
    treasure_hunt_participations
      .where(completed: true)
      .order(completed_at: :asc, time_taken_seconds: :asc)
      .limit(limit)
      .includes(:user)
      .map do |participation|
        {
          user: participation.user,
          rank: participation.rank,
          time_taken: participation.time_taken_seconds,
          clues_found: participation.clues_found,
          completed_at: participation.completed_at,
          prize: calculate_prize(participation.rank)
        }
      end
  end
  
  # Get statistics
  def statistics
    {
      total_participants: participants.count,
      completed_count: treasure_hunt_participations.where(completed: true).count,
      average_time: treasure_hunt_participations.where(completed: true).average(:time_taken_seconds).to_f.round(2),
      fastest_time: treasure_hunt_participations.where(completed: true).minimum(:time_taken_seconds),
      completion_rate: completion_rate,
      difficulty: difficulty,
      total_clues: treasure_hunt_clues.count
    }
  end
  
  # Calculate prize for rank
  def calculate_prize(rank)
    return nil unless prize_pool > 0
    
    case rank
    when 1
      (prize_pool * 0.5).to_i # 50% for 1st place
    when 2
      (prize_pool * 0.3).to_i # 30% for 2nd place
    when 3
      (prize_pool * 0.2).to_i # 20% for 3rd place
    else
      0
    end
  end
  
  # Award prizes to winners
  def award_prizes_to_winners
    leaderboard(limit: 3).each do |entry|
      next if entry[:prize].zero?
      
      entry[:user].increment!(:coins, entry[:prize])
      
      Notification.create!(
        recipient: entry[:user],
        notifiable: self,
        notification_type: 'treasure_hunt_prize',
        title: "Treasure Hunt Prize!",
        message: "You won #{entry[:prize]} coins for finishing #{entry[:rank].ordinalize}!",
        data: { rank: entry[:rank], prize: entry[:prize] }
      )
    end
  end
  
  private
  
  def completion_rate
    return 0 if participants.count.zero?
    
    completed = treasure_hunt_participations.where(completed: true).count
    ((completed.to_f / participants.count) * 100).round(2)
  end
end

