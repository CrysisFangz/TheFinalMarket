class EventParticipation < ApplicationRecord
  belongs_to :seasonal_event
  belongs_to :user
  
  validates :seasonal_event, presence: true
  validates :user, presence: true
  validates :user_id, uniqueness: { scope: :seasonal_event_id }
  
  # Get completed challenges
  def completed_challenges
    seasonal_event.event_challenges.joins(:challenge_completions)
                  .where(challenge_completions: { user_id: user_id })
  end
  
  # Get available challenges
  def available_challenges
    seasonal_event.event_challenges.where(active: true)
  end
  
  # Get progress summary
  def progress_summary
    {
      points: points,
      rank: rank,
      challenges_completed: completed_challenges.count,
      total_challenges: seasonal_event.event_challenges.count,
      completion_percentage: completion_percentage
    }
  end
  
  private
  
  def completion_percentage
    total = seasonal_event.event_challenges.count
    return 0 if total.zero?
    
    ((completed_challenges.count.to_f / total) * 100).round(2)
  end
end

