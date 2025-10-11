class CompetitionTeam < ApplicationRecord
  belongs_to :social_competition
  belongs_to :captain, class_name: 'User'
  has_many :competition_participants
  has_many :members, through: :competition_participants, source: :user
  
  validates :social_competition, presence: true
  validates :captain, presence: true
  validates :name, presence: true, uniqueness: { scope: :social_competition_id }
  
  # Add member to team
  def add_member(user)
    return false if full?
    return false if members.include?(user)
    
    competition_participants.create!(
      user: user,
      social_competition: social_competition,
      registered_at: Time.current
    )
  end
  
  # Remove member from team
  def remove_member(user)
    return false if user == captain
    
    competition_participants.find_by(user: user)&.destroy
  end
  
  # Check if team is full
  def full?
    return false unless max_members
    members.count >= max_members
  end
  
  # Recalculate team score
  def recalculate_score!
    new_score = competition_participants.sum(:score)
    update!(total_score: new_score)
  end
  
  # Get team statistics
  def team_stats
    {
      name: name,
      captain: captain.username,
      members_count: members.count,
      total_score: total_score,
      average_score: average_member_score,
      rank: team_rank
    }
  end
  
  private
  
  def average_member_score
    return 0 if members.count.zero?
    (total_score.to_f / members.count).round(2)
  end
  
  def team_rank
    social_competition.competition_teams
                     .where('total_score > ?', total_score)
                     .count + 1
  end
end

