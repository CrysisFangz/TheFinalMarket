# frozen_string_literal: true

# Service for managing quest progress
class QuestProgressService
  include ServiceResultHelper

  def initialize(quest, user)
    @quest = quest
    @user = user
  end

  def check_progress
    participation = @quest.participation_for(@user)
    return failure('No participation found') unless participation

    total_objectives = @quest.quest_objectives.count
    completed_objectives = 0

    # Optimize: Preload objectives and calculate in one go
    objectives = @quest.quest_objectives.includes(:product, :category)

    objectives.each do |objective|
      if objective.completed_by?(@user)
        completed_objectives += 1
      end
    end

    progress = (completed_objectives.to_f / total_objectives * 100).round(2)
    participation.update!(progress: progress)

    # Check if quest is complete
    if progress >= 100 && !participation.completed?
      complete_quest
    end

    success({
      progress: progress,
      completed_objectives: completed_objectives,
      total_objectives: total_objectives,
      completed: participation.completed?
    })
  rescue ActiveRecord::RecordInvalid => e
    failure("Failed to update progress: #{e.message}")
  end

  private

  def complete_quest
    QuestCompletionService.new(@quest, @user).complete_quest
  end
end