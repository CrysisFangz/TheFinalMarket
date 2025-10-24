# frozen_string_literal: true

module Gamification
  module Commands
    # Command to handle spinning the wheel
    class SpinWheelCommand
      def initialize(spin_to_win_id, user_id)
        @spin_to_win_id = spin_to_win_id
        @user_id = user_id
      end

      def execute
        spin_to_win = SpinToWin.find(spin_to_win_id)
        user = User.find(user_id)

        service = Gamification::SpinService.new(spin_to_win, user)
        service.spin!
      end

      private

      attr_reader :spin_to_win_id, :user_id
    end
  end
end