# frozen_string_literal: true

class AwardPrizeJob < ApplicationJob
  queue_as :default

  def perform(user_id, prize_id)
    user = User.find(user_id)
    prize = SpinToWinPrize.find(prize_id)

    case prize.prize_type.to_sym
    when :coins
      user.increment!(:coins, prize.prize_value)
    when :discount_code
      create_discount_code(user, prize)
    when :free_shipping
      create_free_shipping_voucher(user, prize)
    when :product
      create_product_voucher(user, prize)
    when :experience_points
      user.increment!(:experience_points, prize.prize_value)
    when :loyalty_tokens
      user.loyalty_token&.earn(prize.prize_value, 'spin_to_win')
    end
  rescue => e
    Rails.logger.error("Failed to award prize: #{e.message}", user_id: user_id, prize_id: prize_id)
    # Optionally retry or handle failure
  end

  private

  def create_discount_code(user, prize)
    # Implementation depends on your discount system
  end

  def create_free_shipping_voucher(user, prize)
    # Implementation depends on your voucher system
  end

  def create_product_voucher(user, prize)
    # Implementation depends on your voucher system
  end
end