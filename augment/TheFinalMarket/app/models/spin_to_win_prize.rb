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
  
  # Get display value
  def display_value
    case prize_type.to_sym
    when :coins
      "#{prize_value} Coins"
    when :discount_code
      "#{prize_value}% Off"
    when :free_shipping
      "Free Shipping"
    when :product
      "Free Product"
    when :experience_points
      "#{prize_value} XP"
    when :loyalty_tokens
      "#{prize_value} Tokens"
    when :mystery_box
      "Mystery Box"
    end
  end
  
  # Get times won
  def times_won
    spin_to_win_spins.count
  end
end

