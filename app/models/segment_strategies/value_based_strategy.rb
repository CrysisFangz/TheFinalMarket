# frozen_string_literal: true

module SegmentStrategies
  # Strategy for value-based segmentation
  class ValueBasedStrategy < BaseStrategy
    def user_ids_for_segment
      validate_criteria('min_value')

      User.joins(:orders)
          .where(orders: { status: 'completed' })
          .group('users.id')
          .having('SUM(orders.total_cents) >= ?', criteria_value('min_value', 0))
          .pluck('users.id')
    end
  end
end