class SubmitAnswerService
  def initialize(participation, answer)
    @participation = participation
    @answer = answer
  end

  def call
    return { success: false, message: 'No more clues' } unless current_clue

    ActiveRecord::Base.transaction do
      attempt = record_attempt
      handle_attempt(attempt)
    rescue StandardError => e
      Rails.logger.error("Submit answer error: #{e.message}")
      { success: false, message: "Error processing answer: #{e.message}" }
    end
  rescue ActiveRecord::RecordInvalid => e
    { success: false, message: "Error recording attempt: #{e.message}" }
  end</search>

  private

  attr_reader :participation, :answer

  def current_clue
    @current_clue ||= participation.treasure_hunt.treasure_hunt_clues.order(:clue_order)[participation.current_clue_index]
  end

  def record_attempt
    participation.clue_attempts.create!(
      treasure_hunt_clue: current_clue,
      answer: answer,
      correct: current_clue.correct_answer?(answer),
      attempted_at: Time.current
    )
  end

  def handle_attempt(attempt)
    if attempt.correct?
      participation.increment!(:clues_found)
      participation.increment!(:current_clue_index)

      if hunt_completed?
        CompleteHuntService.new(participation).call
        { success: true, completed: true, message: 'Treasure hunt completed!' }
      else
        { success: true, completed: false, message: 'Correct! Moving to next clue.' }
      end
    else
      participation.increment!(:incorrect_attempts)
      { success: false, message: 'Incorrect answer. Try again!' }
    end
  end

  def hunt_completed?
    participation.current_clue_index >= participation.treasure_hunt.treasure_hunt_clues.count
  end
end