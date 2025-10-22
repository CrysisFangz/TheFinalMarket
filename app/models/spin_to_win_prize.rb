class SpinToWinPrize < ApplicationRecord
  belongs_to :spin_to_win
  has_many :spin_to_win_spins

  validates :spin_to_win, presence: true
  validates :prize_name, presence: true
  validates :prize_type, presence: true
  validates :probability, numericality: { greater_than: 0, less_than_or_equal_to: 100 }

  enum prize_type: {
    coins: 0,
    discount_code: 1,
    free_shipping: 2,
    product: 3,
    experience_points: 4,
    loyalty_tokens: 5,
    mystery_box: 6
  }

  # Optimized indexes
  index :spin_to_win_id
  index :prize_type
  index :active
end

