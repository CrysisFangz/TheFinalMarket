class QuestParticipation < ApplicationRecord
  belongs_to :shopping_quest
  belongs_to :user
  
  validates :shopping_quest, presence: true
  validates :user, presence: true
  validates :user_id, uniqueness: { scope: :shopping_quest_id }
  
  # Get objectives progress
  def objectives_progress
    shopping_quest.quest_objectives.map do |objective|
      {
        objective: objective,
        description: objective.display_text,
        current: objective.current_progress(user),
        target: objective.target_value,
        progress: objective.progress_percentage(user),
        completed: objective.completed_by?(user)
      }
    end
  end
  
  # Check if all objectives are complete
  def all_objectives_complete?
    shopping_quest.quest_objectives.all? { |obj| obj.completed_by?(user) }
  end
end

