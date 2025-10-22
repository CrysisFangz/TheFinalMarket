# frozen_string_literal: true

module Gamification
  module Queries
    # Query to retrieve user's spin history
    class UserSpinHistoryQuery
      def initialize(user_id, limit: 10)
        @user_id = user_id
        @limit = limit
      end

      def execute
        SpinToWinSpin.where(user_id: user_id)
                     .order(spun_at: :desc)
                     .limit(limit)
                     .includes(:spin_to_win_prize, :spin_to_win)
      end

      private

      attr_reader :user_id, :limit
    end
  end
end