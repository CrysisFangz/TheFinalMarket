# frozen_string_literal: true

module SegmentStrategies
  # Strategy for RFM (Recency, Frequency, Monetary) segmentation
  class RfmStrategy < BaseStrategy
    RFM_CRITERIA_DEFAULTS = {
      'recency_days' => 30,
      'min_frequency' => 1,
      'min_monetary' => 0
    }.freeze

    def user_ids_for_segment
      validate_criteria('recency_days', 'min_frequency', 'min_monetary')

      User.joins(:orders)
          .where(orders: { status: 'completed' })
          .group('users.id')
          .having('MAX(orders.created_at) > ?', criteria_value('recency_days', 30).days.ago)
          .having('COUNT(orders.id) >= ?', criteria_value('min_frequency', 1))
          .having('SUM(orders.total_cents) >= ?', criteria_value('min_monetary', 0))
          .pluck('users.id')
    end
  end
end