class TreasureHuntParticipation < ApplicationRecord
  belongs_to :treasure_hunt
  belongs_to :user
  has_many :clue_attempts, dependent: :destroy
  
  validates :treasure_hunt, presence: true
  validates :user, presence: true
  validates :user_id, uniqueness: { scope: :treasure_hunt_id }
  
  # Submit answer for current clue
  def submit_answer(answer)
    current_clue = treasure_hunt.treasure_hunt_clues.order(:clue_order)[current_clue_index]
    return { success: false, message: 'No more clues' } unless current_clue
    
    # Record attempt
    attempt = clue_attempts.create!(
      treasure_hunt_clue: current_clue,
      answer: answer,
      correct: current_clue.correct_answer?(answer),
      attempted_at: Time.current
    )
    
    if attempt.correct?
      # Move to next clue
      increment!(:clues_found)
      increment!(:current_clue_index)
      
      # Check if hunt is complete
      if current_clue_index >= treasure_hunt.treasure_hunt_clues.count
        complete_hunt!
        return { success: true, completed: true, message: 'Treasure hunt completed!' }
      end
      
      { success: true, completed: false, message: 'Correct! Moving to next clue.' }
    else
      increment!(:incorrect_attempts)
      { success: false, message: 'Incorrect answer. Try again!' }
    end
  end
  
  # Use a hint
  def use_hint(hint_level = 1)
    return nil if hints_used >= max_hints_allowed
    
    current_clue = treasure_hunt.treasure_hunt_clues.order(:clue_order)[current_clue_index]
    return nil unless current_clue
    
    hint = current_clue.get_hint(hint_level)
    increment!(:hints_used) if hint
    
    hint
  end
  
  # Complete the hunt
  def complete_hunt!
    time_taken = (Time.current - started_at).to_i
    
    update!(
      completed: true,
      completed_at: Time.current,
      time_taken_seconds: time_taken,
      rank: calculate_rank
    )
    
    # Award completion rewards
    award_completion_rewards
  end
  
  # Get current clue
  def current_clue
    treasure_hunt.treasure_hunt_clues.order(:clue_order)[current_clue_index]
  end
  
  # Get progress percentage
  def progress_percentage
    total_clues = treasure_hunt.treasure_hunt_clues.count
    return 100 if total_clues.zero?
    
    ((clues_found.to_f / total_clues) * 100).round(2)
  end
  
  # Get statistics
  def stats
    {
      clues_found: clues_found,
      total_clues: treasure_hunt.treasure_hunt_clues.count,
      progress: progress_percentage,
      incorrect_attempts: incorrect_attempts,
      hints_used: hints_used,
      time_elapsed: time_elapsed,
      completed: completed?,
      rank: rank
    }
  end
  
  private
  
  def calculate_rank
    # Count how many people completed before this user
    treasure_hunt.treasure_hunt_participations
                 .where(completed: true)
                 .where('completed_at < ?', completed_at)
                 .count + 1
  end
  
  def award_completion_rewards
    # Base reward
    base_reward = case treasure_hunt.difficulty.to_sym
    when :easy
      100
    when :medium
      250
    when :hard
      500
    when :expert
      1000
    end
    
    # Bonus for speed
    speed_bonus = rank <= 3 ? base_reward * 0.5 : 0
    
    # Penalty for hints
    hint_penalty = hints_used * (base_reward * 0.1)
    
    total_reward = (base_reward + speed_bonus - hint_penalty).to_i
    
    user.increment!(:coins, total_reward)
    user.increment!(:experience_points, total_reward / 2)
  end
  
  def time_elapsed
    return time_taken_seconds if completed?
    (Time.current - started_at).to_i
  end
  
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

