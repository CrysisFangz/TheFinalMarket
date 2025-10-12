class CompetitionParticipant < ApplicationRecord
  belongs_to :social_competition
  belongs_to :user
  belongs_to :competition_team, optional: true
  
  validates :social_competition, presence: true
  validates :user, presence: true
  validates :user_id, uniqueness: { scope: :social_competition_id }
  
  # Get performance stats
  def performance_stats
    {
      score: score,
      rank: rank,
      team: competition_team&.name,
      registered_at: registered_at,
      time_in_competition: time_in_competition
    }
  end
  
  private
  
  def time_in_competition
    return 0 unless social_competition.started_at
    
    end_time = social_competition.ended_at || Time.current
    ((end_time - social_competition.started_at) / 1.day).round(1)
  end
end

