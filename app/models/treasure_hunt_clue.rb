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

  after_update :log_state_change

  # Delegate business logic to services
  def correct_answer?(answer)
    TreasureHunt::ClueValidationService.new(self, answer).call.success?
  end

  def get_hint(hint_level = 1)
    service = TreasureHunt::HintService.new(self, hint_level)
    result = service.call
    result.success? ? result.data : nil
  end

  def generate_qr_code!
    TreasureHunt::QRCodeService.new(self).call
  end

  private

  def log_state_change
    Rails.logger.info("TreasureHuntClue state changed: id=#{id}, changes=#{changes}")
  end
end

