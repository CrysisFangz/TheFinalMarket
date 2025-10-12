class SpinToWin < ApplicationRecord
  has_many :spin_to_win_prizes, dependent: :destroy
  has_many :spin_to_win_spins, dependent: :destroy
  
  validates :name, presence: true
  validates :status, presence: true
  validates :spins_per_user_per_day, numericality: { greater_than: 0 }
  
  enum status: {
    inactive: 0,
    active: 1,
    paused: 2
  }
  
  # Scopes
  scope :active_wheels, -> { where(status: :active) }
  
  # Check if user can spin
  def can_spin?(user)
    return false unless active?
    return false if requires_purchase? && !user_made_purchase_today?(user)
    
    spins_today = user_spins_today(user)
    spins_today < spins_per_user_per_day
  end
  
  # Get remaining spins for user
  def remaining_spins(user)
    return 0 unless active?
    
    spins_today = user_spins_today(user)
    [spins_per_user_per_day - spins_today, 0].max
  end
  
  # Spin the wheel
  def spin!(user)
    return { success: false, message: 'Cannot spin at this time' } unless can_spin?(user)
    
    # Select a prize based on probability
    prize = select_prize
    
    return { success: false, message: 'No prizes available' } unless prize
    
    # Record the spin
    spin_record = spin_to_win_spins.create!(
      user: user,
      spin_to_win_prize: prize,
      spun_at: Time.current
    )
    
    # Award the prize
    award_prize(user, prize)
    
    {
      success: true,
      prize: prize,
      remaining_spins: remaining_spins(user),
      message: "You won: #{prize.prize_name}!"
    }
  end
  
  # Get user's spin history
  def user_spin_history(user, limit: 10)
    spin_to_win_spins.where(user: user)
                     .order(spun_at: :desc)
                     .limit(limit)
                     .includes(:spin_to_win_prize)
  end
  
  # Get statistics
  def statistics
    {
      total_spins: spin_to_win_spins.count,
      unique_spinners: spin_to_win_spins.distinct.count(:user_id),
      prizes_awarded: spin_to_win_spins.count,
      most_common_prize: most_common_prize,
      total_value_awarded: total_value_awarded
    }
  end
  
  # Get prize distribution
  def prize_distribution
    spin_to_win_prizes.map do |prize|
      {
        prize_name: prize.prize_name,
        probability: prize.probability,
        times_won: spin_to_win_spins.where(spin_to_win_prize: prize).count,
        value: prize.prize_value
      }
    end
  end
  
  private
  
  def user_spins_today(user)
    spin_to_win_spins.where(user: user)
                     .where('spun_at >= ?', Time.current.beginning_of_day)
                     .count
  end
  
  def user_made_purchase_today?(user)
    user.orders.where('created_at >= ?', Time.current.beginning_of_day)
        .where(status: 'completed')
        .exists?
  end
  
  def select_prize
    # Get all active prizes
    prizes = spin_to_win_prizes.where(active: true)
    return nil if prizes.empty?
    
    # Calculate total probability
    total_probability = prizes.sum(:probability)
    
    # Generate random number
    random = rand(0.0..total_probability)
    
    # Select prize based on probability
    cumulative = 0.0
    prizes.each do |prize|
      cumulative += prize.probability
      return prize if random <= cumulative
    end
    
    # Fallback to first prize
    prizes.first
  end
  
  def award_prize(user, prize)
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
    
    # Send notification
    Notification.create!(
      recipient: user,
      notifiable: prize,
      notification_type: 'spin_to_win_prize',
      title: 'Spin to Win Prize!',
      message: "You won: #{prize.prize_name}!",
      data: { prize_type: prize.prize_type, prize_value: prize.prize_value }
    )
  end
  
  def create_discount_code(user, prize)
    # Create a discount code for the user
    # Implementation depends on your discount system
  end
  
  def create_free_shipping_voucher(user, prize)
    # Create a free shipping voucher
    # Implementation depends on your voucher system
  end
  
  def create_product_voucher(user, prize)
    # Create a product voucher
    # Implementation depends on your voucher system
  end
  
  def most_common_prize
    spin_to_win_spins.group(:spin_to_win_prize_id)
                     .count
                     .max_by { |_, count| count }
                     &.first
                     &.then { |id| SpinToWinPrize.find(id).prize_name }
  end
  
  def total_value_awarded
    spin_to_win_spins.joins(:spin_to_win_prize)
                     .where(spin_to_win_prizes: { prize_type: [:coins, :experience_points] })
                     .sum('spin_to_win_prizes.prize_value')
  end
end

