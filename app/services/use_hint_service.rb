class UseHintService
  def initialize(participation, hint_level = 1)
    @participation = participation
    @hint_level = hint_level
  end

  def call
    return nil if participation.hints_used >= max_hints_allowed
    return nil unless current_clue

    hint = current_clue.get_hint(hint_level)
    participation.increment!(:hints_used) if hint
    hint
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Error using hint: #{e.message}")
    nil
  end</search>

  private

  attr_reader :participation, :hint_level

  def current_clue
    @current_clue ||= participation.treasure_hunt.treasure_hunt_clues.order(:clue_order)[participation.current_clue_index]
  end

  def max_hints_allowed
    case participation.treasure_hunt.difficulty.to_sym
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