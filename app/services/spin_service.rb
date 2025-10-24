# frozen_string_literal: true

# Service for handling spin logic
class SpinService
  def initialize(spin_to_win)
    @spin_to_win = spin_to_win
  end

  def spin!(user)
    return { success: false, message: 'Cannot spin at this time' } unless can_spin?(user)

        circuit_breaker.execute do
      prize = select_prize
      return { success: false, message: 'No prizes available' } unless prize

      spin_record = record_spin(user, prize)
      award_prize(user, prize)

      # Record metrics for observability
      record_spin_metrics(user, prize, true)

      {
        success: true,
        prize: prize,
        remaining_spins: remaining_spins(user),
        message: "You won: #{prize.prize_name}!"
      }
    end</search>
</search_and_replace>
    rescue CircuitBreaker::Open => e
    Rails.logger.warn("Circuit breaker open for spin: #{e.message}")
    record_spin_metrics(user, nil, false)
    { success: false, message: 'Service temporarily unavailable, please try again later' }
  rescue => e
    Rails.logger.error("Spin failed: #{e.message}", user_id: user.id, spin_to_win_id: @spin_to_win.id)
    record_spin_metrics(user, nil, false)
    { success: false, message: 'An error occurred while spinning' }</search>
</search_and_replace>
  end

  def can_spin?(user)
    return false unless @spin_to_win.active?
    return false if requires_purchase? && !user_made_purchase_today?(user)

    spins_today = user_spins_today(user)
    spins_today < @spin_to_win.spins_per_user_per_day
  end

  def remaining_spins(user)
    return 0 unless @spin_to_win.active?

    spins_today = user_spins_today(user)
    [@spin_to_win.spins_per_user_per_day - spins_today, 0].max
  end

  def user_spin_history(user, limit: 10)
    @spin_to_win.spin_to_win_spins.where(user: user)
                                  .order(spun_at: :desc)
                                  .limit(limit)
                                  .includes(:spin_to_win_prize)
  end

    private

  def circuit_breaker
    @circuit_breaker ||= CircuitBreaker.new(failure_threshold: 3, recovery_timeout: 60.seconds)
  end

  def select_prize</search>
</search_and_replace>
    PrizeSelector.new(@spin_to_win).select_prize
  end

  def record_spin(user, prize)
    spin_record = @spin_to_win.spin_to_win_spins.new(
      user: user,
      spin_to_win_prize: prize,
      spun_at: Time.current
    )
    spin_record.save!
    spin_record.apply_event(SpinCreated.new(spin_record))
    spin_record
  end

  def award_prize(user, prize)
    PrizeAwarder.new(user, prize).award!
  end

  def user_spins_today(user)
    @spin_to_win.spin_to_win_spins.where(user: user)
                                  .where('spun_at >= ?', Time.current.beginning_of_day)
                                  .count
  end

  def user_made_purchase_today?(user)
    user.orders.where('created_at >= ?', Time.current.beginning_of_day)
               .where(status: 'completed')
               .exists?
  end

    def requires_purchase?
    @spin_to_win.requires_purchase?
  end

  def record_spin_metrics(user, prize, success)
    metrics = {
      spin_to_win_id: @spin_to_win.id,
      user_id: user.id,
      prize_id: prize&.id,
      prize_type: prize&.prize_type,
      success: success,
      timestamp: Time.current
    }
    Rails.logger.info("Spin metrics: #{metrics}")
    # In a real system, send to monitoring service like DataDog or Prometheus
  end
end</search>
</search_and_replace>