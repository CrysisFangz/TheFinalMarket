# frozen_string_literal: true

require 'test_helper'

module Gamification
  class SpinServiceTest < ActiveSupport::TestCase
    setup do
      @spin_to_win = spin_to_wins(:active_wheel)
      @user = users(:one)
    end

    test 'can_spin? returns true for eligible user' do
      service = SpinService.new(@spin_to_win, @user)
      assert service.can_spin?
    end

    test 'spin! returns success for valid spin' do
      service = SpinService.new(@spin_to_win, @user)
      result = service.spin!

      assert result.success
      assert_not_nil result.data[:prize]
    end

    test 'spin! returns failure when cannot spin' do
      # Simulate user exceeding daily spins
      @spin_to_win.update!(spins_per_user_per_day: 0)
      service = SpinService.new(@spin_to_win, @user)
      result = service.spin!

      assert_not result.success
      assert_equal 'Cannot spin at this time', result.message
    end
  end
end