# frozen_string_literal: true

# Service for managing quest participation progress and completion tracking.
# Ensures accurate progress calculation and efficient quest management.
class QuestParticipationService
  # Gets objectives progress for a quest participation.
  # @param participation [QuestParticipation] The quest participation.
  # @return [Array<Hash>] Array of objective progress data.
  def self.get_objectives_progress(participation)
    cache_key = "quest_participation:#{participation.id}:objectives_progress"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      participation.shopping_quest.quest_objectives.map do |objective|
        {
          objective: objective,
          description: objective.display_text,
          current: QuestProgressService.calculate_progress(objective, participation.user),
          target: objective.target_value,
          progress: QuestProgressService.calculate_progress_percentage(objective, participation.user),
          completed: objective.completed_by?(participation.user)
        }
      end
    end
  rescue StandardError => e
    Rails.logger.error("Failed to get objectives progress for participation #{participation.id}: #{e.message}")
    []
  end

  # Checks if all objectives are complete for a participation.
  # @param participation [QuestParticipation] The quest participation.
  # @return [Boolean] True if all objectives are complete.
  def self.all_objectives_complete?(participation)
    participation.shopping_quest.quest_objectives.all? do |objective|
      objective.completed_by?(participation.user)
    end
  end

  # Calculates overall quest completion percentage.
  # @param participation [QuestParticipation] The quest participation.
  # @return [Float] Completion percentage (0-100).
  def self.calculate_completion_percentage(participation)
    objectives = participation.shopping_quest.quest_objectives
    return 0.0 if objectives.empty?

    total_progress = objectives.sum do |objective|
      QuestProgressService.calculate_progress_percentage(objective, participation.user)
    end

    (total_progress / objectives.count).round(2)
  end
end