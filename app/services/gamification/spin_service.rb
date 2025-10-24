# frozen_string_literal: true

require 'gamification_events'
require 'infrastructure/gamification/spin_circuit_breaker'

module Gamification
  # Service for handling spin-to-win operations
  class SpinService
    include ActiveModel::Validations

    attr_reader :spin_to_win, :user

    def initialize(spin_to_win, user)
      @spin_to_win = spin_to_win
      @user = user
      validate_inputs
    end

    def can_spin?
      return false unless spin_to_win.active?
      return false if requires_purchase? && !user_made_purchase_today?

      spins_today < spin_to_win.spins_per_user_per_day
    end

    def remaining_spins
      return 0 unless spin_to_win.active?

      [spin_to_win.spins_per_user_per_day - spins_today, 0].max
    end

    def spin!
      circuit_breaker = Infrastructure::Gamification::SpinCircuitBreaker.new

      circuit_breaker.execute do
        return Result.failure('Cannot spin at this time') unless can_spin?

        prize = select_prize
        return Result.failure('No prizes available') unless prize

        spin_record = create_spin_record(prize)
        award_prize(prize, spin_record)

        Result.success(
          prize: prize,
          remaining_spins: remaining_spins,
          message: "You won: #{prize.prize_name}!"
        )
      end
    rescue => e
      Result.failure("Spin failed: #{e.message}")
    end

    private

    def validate_inputs
      errors.add(:spin_to_win, 'must be active') unless spin_to_win.is_a?(SpinToWin)
      errors.add(:user, 'must be present') unless user.is_a?(User)
    end

    def requires_purchase?
      spin_to_win.requires_purchase?
    end

    def user_made_purchase_today?
      user.orders.where('created_at >= ?', Time.current.beginning_of_day)
          .where(status: 'completed')
          .exists?
    end

    def spins_today
      spin_to_win.spin_to_win_spins.where(user: user)
                  .where('spun_at >= ?', Time.current.beginning_of_day)
                  .count
    end

    def select_prize
      prizes = spin_to_win.spin_to_win_prizes.where(active: true)
      return nil if prizes.empty?

      total_probability = prizes.sum(:probability)
      random = rand(0.0..total_probability)

      cumulative = 0.0
      prizes.each do |prize|
        cumulative += prize.probability
        return prize if random <= cumulative
      end

      prizes.first
    end

    def create_spin_record(prize)
      spin_to_win.spin_to_win_spins.create!(
        user: user,
        spin_to_win_prize: prize,
        spun_at: Time.current
      )
    end

    def award_prize(prize, spin_record)
      balance_before = get_user_balance(prize.prize_type)

      case prize.prize_type.to_sym
      when :coins
        user.increment!(:coins, prize.prize_value)
      when :discount_code
        create_discount_code(prize)
      when :free_shipping
        create_free_shipping_voucher(prize)
      when :product
        create_product_voucher(prize)
      when :experience_points
        user.increment!(:experience_points, prize.prize_value)
      when :loyalty_tokens
        user.loyalty_token&.earn(prize.prize_value, 'spin_to_win')
      end

      balance_after = get_user_balance(prize.prize_type)

      # Publish events
      GamificationEvents::EventStore.append(
        GamificationEvents::SpinOccurredEvent.new(spin_to_win, user, prize, { remaining_spins: remaining_spins })
      )

      GamificationEvents::EventStore.append(
        GamificationEvents::PrizeAwardedEvent.new(user, prize, {
          balance_before: balance_before,
          balance_after: balance_after
        })
      )
    end

    def create_discount_code(prize)
      # Implementation for discount code creation
    end

    def create_free_shipping_voucher(prize)
      # Implementation for voucher creation
    end

    def create_product_voucher(prize)
      # Implementation for voucher creation
    end

    def get_user_balance(prize_type)
      case prize.prize_type.to_sym
      when :coins
        user.coins
      when :experience_points
        user.experience_points
      else
        0
      end
    end

    # Result class for service responses
    class Result
      attr_reader :success, :data, :message

      def self.success(data)
        new(true, data, nil)
      end

      def self.failure(message)
        new(false, nil, message)
      end

      private

      def initialize(success, data, message)
        @success = success
        @data = data
        @message = message
      end
    end
  end
end