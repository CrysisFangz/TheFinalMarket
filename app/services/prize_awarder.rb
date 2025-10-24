# frozen_string_literal: true

# Service for awarding prizes to users
class PrizeAwarder
  def initialize(user, prize)
    @user = user
    @prize = prize
  end

  def award!
    # Send notification immediately
    send_notification

    # Award prize asynchronously
    AwardPrizeJob.perform_later(@user.id, @prize.id)
  rescue => e
    Rails.logger.error("Prize awarding failed: #{e.message}", user_id: @user.id, prize_id: @prize.id)
  end

  private

  def send_notification
    Notification.create!(
      recipient: @user,
      notifiable: @prize,
      notification_type: 'spin_to_win_prize',
      title: 'Spin to Win Prize!',
      message: "You won: #{@prize.prize_name}!",
      data: { prize_type: @prize.prize_type, prize_value: @prize.prize_value }
    )
  end

  def create_discount_code
    # Implementation depends on your discount system
    # Placeholder for now
  end

  def create_free_shipping_voucher
    # Implementation depends on your voucher system
    # Placeholder for now
  end

  def create_product_voucher
    # Implementation depends on your voucher system
    # Placeholder for now
  end
end