class SocialCompetition < ApplicationRecord
  has_many :competition_participants, dependent: :destroy
  has_many :participants, through: :competition_participants, source: :user
  has_many :competition_teams, dependent: :destroy
  
  validates :name, presence: true
  validates :competition_type, presence: true
  validates :status, presence: true
  
  enum competition_type: {
    individual: 0,
    team: 1,
    guild: 2,
    bracket: 3
  }
  
  enum status: {
    registration: 0,
    active: 1,
    finished: 2,
    cancelled: 3
  }
  
  enum scoring_type: {
    points: 0,
    purchases: 1,
    sales: 2,
    reviews: 3,
    referrals: 4,
    engagement: 5
  }
  
  # Scopes
  scope :active_competitions, -> { where(status: :active) }
  scope :open_for_registration, -> { where(status: :registration).where('registration_ends_at > ?', Time.current) }
  
  # Register user for competition
  def register(user, team_id: nil)
    return false unless can_register?(user)
    
    participant = competition_participants.create!(
      user: user,
      competition_team_id: team_id,
      registered_at: Time.current,
      score: 0
    )
    
    participant
  end
  
  # Check if user can register
  def can_register?(user)
    registration? &&
    registration_ends_at > Time.current &&
    !participants.include?(user) &&
    (max_participants.nil? || participants.count < max_participants)
  end
  
  # Start competition
  def start!
    update!(status: :active, started_at: Time.current)
    notify_participants('Competition has started!')
  end
  
  # End competition
  def finish!
    update!(status: :finished, ended_at: Time.current)
    calculate_final_rankings
    award_prizes
  end
  
  # Update score for user
  def update_score(user, points)
    participant = competition_participants.find_by(user: user)
    return unless participant
    
    participant.increment!(:score, points)
    
    # Update team score if team competition
    if team?
      participant.competition_team&.recalculate_score!
    end
    
    update_rankings
  end
  
  # Get leaderboard
  def leaderboard(limit: 100)
    if team?
      team_leaderboard(limit)
    else
      individual_leaderboard(limit)
    end
  end
  
  # Get user's rank
  def user_rank(user)
    participant = competition_participants.find_by(user: user)
    return nil unless participant
    
    participant.rank
  end
  
  # Get statistics
  def statistics
    {
      total_participants: participants.count,
      total_teams: competition_teams.count,
      total_score: competition_participants.sum(:score),
      average_score: competition_participants.average(:score).to_f.round(2),
      top_score: competition_participants.maximum(:score),
      competition_type: competition_type,
      status: status,
      days_remaining: days_remaining
    }
  end
  
  private
  
  def individual_leaderboard(limit)
    competition_participants
      .order(score: :desc, registered_at: :asc)
      .limit(limit)
      .includes(:user)
      .map.with_index(1) do |participant, index|
        {
          rank: index,
          user: participant.user,
          score: participant.score,
          prize: calculate_prize(index)
        }
      end
  end
  
  def team_leaderboard(limit)
    competition_teams
      .order(total_score: :desc, created_at: :asc)
      .limit(limit)
      .map.with_index(1) do |team, index|
        {
          rank: index,
          team: team,
          score: team.total_score,
          members: team.members.count,
          prize: calculate_prize(index)
        }
      end
  end
  
  def update_rankings
    competition_participants.order(score: :desc, registered_at: :asc).each.with_index(1) do |participant, index|
      participant.update_column(:rank, index)
    end
  end
  
  def calculate_final_rankings
    update_rankings
  end
  
  def award_prizes
    leaderboard(limit: prize_positions || 3).each do |entry|
      next unless entry[:prize] > 0
      
      if team?
        award_team_prize(entry[:team], entry[:prize])
      else
        award_individual_prize(entry[:user], entry[:prize], entry[:rank])
      end
    end
  end
  
  def award_individual_prize(user, prize, rank)
    user.increment!(:coins, prize)
    
    Notification.create!(
      recipient: user,
      notifiable: self,
      notification_type: 'competition_prize',
      title: "Competition Prize!",
      message: "You finished #{rank.ordinalize} in #{name}!",
      data: { rank: rank, prize: prize }
    )
  end
  
  def award_team_prize(team, prize)
    prize_per_member = (prize / team.members.count.to_f).to_i
    
    team.members.each do |member|
      member.increment!(:coins, prize_per_member)
      
      Notification.create!(
        recipient: member,
        notifiable: self,
        notification_type: 'competition_prize',
        title: "Team Competition Prize!",
        message: "Your team won #{prize} coins in #{name}!",
        data: { team_prize: prize, individual_share: prize_per_member }
      )
    end
  end
  
  def calculate_prize(rank)
    return 0 unless prize_pool > 0
    
    case rank
    when 1
      (prize_pool * 0.5).to_i
    when 2
      (prize_pool * 0.3).to_i
    when 3
      (prize_pool * 0.2).to_i
    else
      0
    end
  end
  
  def notify_participants(message)
    participants.find_each do |user|
      Notification.create!(
        recipient: user,
        notifiable: self,
        notification_type: 'competition_update',
        title: name,
        message: message
      )
    end
  end
  
  def days_remaining
    return 0 unless active?
    return 0 if ends_at < Time.current
    
    ((ends_at - Time.current) / 1.day).ceil
  end
end

