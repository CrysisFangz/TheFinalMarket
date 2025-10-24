# Presenter for SpinToWinPrize - Decouples presentation logic from the model
class SpinToWinPrizePresenter
  def initialize(prize)
    @prize = prize
  end

  def display_value
    case @prize.prize_type.to_sym
    when :coins
      "#{@prize.prize_value} Coins"
    when :discount_code
      "#{@prize.prize_value}% Off"
    when :free_shipping
      "Free Shipping"
    when :product
      "Free Product"
    when :experience_points
      "#{@prize.prize_value} XP"
    when :loyalty_tokens
      "#{@prize.prize_value} Tokens"
    when :mystery_box
      "Mystery Box"
    else
      @prize.prize_name
    end
  end

  def times_won_display
    "#{@prize.times_won} times won"
  end

  def probability_display
    "#{@prize.probability}% chance"
  end
end