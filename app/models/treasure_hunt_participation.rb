class TreasureHuntParticipation < ApplicationRecord
  belongs_to :treasure_hunt
  belongs_to :user
  has_many :clue_attempts, dependent: :destroy

  validates :treasure_hunt, presence: true
  validates :user, presence: true
  validates :user_id, uniqueness: { scope: :treasure_hunt_id }

  # Scopes for optimized queries
  scope :completed, -> { where(completed: true) }
  scope :ordered_by_completion, -> { order(completed_at: :asc) }

  # Delegate business logic to services
  def submit_answer(answer)
    SubmitAnswerService.new(self, answer).call
  end

  def use_hint(hint_level = 1)
    UseHintService.new(self, hint_level).call
  end

  def complete_hunt!
    CompleteHuntService.new(self).call
  end

  # Get current clue with optimization
  def current_clue
    @current_clue ||= treasure_hunt.treasure_hunt_clues.order(:clue_order).offset(current_clue_index).first
  end

  # Get statistics using presenter
  def stats
    ParticipationStatsPresenter.new(self).stats
  end

  # Optimized progress calculation
  def progress_percentage
    ProgressCalculator.new(self).call
  end

  # Optimized time elapsed
  def time_elapsed
    return time_taken_seconds if completed?
    (Time.current - started_at).to_i
  end

  # Optimized rank calculation
  def calculate_rank
    RankCalculator.new(self).call
  end

  private

  # Max hints allowed based on difficulty
  def max_hints_allowed
    case treasure_hunt.difficulty.to_sym
    when :easy
      3
    when :medium
      2
    when :hard
      1
    when :expert
      0
    end
  end
end

