class TreasureHuntClue < ApplicationRecord
  belongs_to :treasure_hunt
  belongs_to :product, optional: true
  belongs_to :category, optional: true
  
  validates :treasure_hunt, presence: true
  validates :clue_text, presence: true
  validates :clue_order, presence: true
  validates :clue_type, presence: true
  
  enum clue_type: {
    product_based: 0,
    category_based: 1,
    location_based: 2,
    riddle: 3,
    image_based: 4,
    qr_code: 5
  }
  
  # Check if answer is correct
  def correct_answer?(answer)
    return false if answer.blank?
    
    case clue_type.to_sym
    when :product_based
      answer.to_i == product_id
    when :category_based
      answer.to_i == category_id
    when :riddle, :location_based
      normalize_answer(answer) == normalize_answer(correct_answer)
    when :qr_code
      answer == qr_code_value
    else
      false
    end
  end
  
  # Get hint (if available)
  def get_hint(hint_level = 1)
    hints = hint_text&.split('||') || []
    hints[hint_level - 1]
  end
  
  # Generate QR code for this clue
  def generate_qr_code!
    return unless qr_code?
    
    require 'securerandom'
    code = SecureRandom.hex(16)
    update!(qr_code_value: code)
    code
  end
  
  private
  
  def normalize_answer(text)
    text.to_s.downcase.strip.gsub(/[^a-z0-9]/, '')
  end
end

