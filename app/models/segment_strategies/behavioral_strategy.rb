# frozen_string_literal: true

module SegmentStrategies
  # Strategy for behavioral segmentation
  class BehavioralStrategy < BaseStrategy
    def user_ids_for_segment
      # Behavioral segmentation can be extended based on specific behavioral patterns
      # For now, return empty array as base implementation
      # This can be enhanced with specific behavioral criteria like:
      # - Product view patterns
      # - Cart abandonment behavior
      # - Search behavior
      # - Time spent on site
      # - Feature usage patterns

      Rails.logger.info(
        "BehavioralStrategy executed for segment #{segment.id}",
        segment_name: segment.name,
        criteria: criteria
      )

      []
    end
  end
end