# frozen_string_literal: true

module SegmentStrategies
  # Strategy for engagement-based segmentation
  class EngagementStrategy < BaseStrategy
    def user_ids_for_segment
      validate_criteria('min_logins', 'active_days')

      User.where('sign_in_count >= ?', criteria_value('min_logins', 1))
          .where('last_sign_in_at > ?', criteria_value('active_days', 7).days.ago)
          .pluck(:id)
    end
  end
end