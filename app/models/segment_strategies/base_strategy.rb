# frozen_string_literal: true

module SegmentStrategies
  # Base class for all segment strategies
  class BaseStrategy
    attr_reader :segment

    def initialize(segment)
      @segment = segment
    end

    # Abstract method to be implemented by subclasses
    def user_ids_for_segment
      raise NotImplementedError, "#{self.class.name} must implement #user_ids_for_segment"
    end

    protected

    # Get criteria with defaults merged
    def criteria
      @criteria ||= segment.criteria_config
    end

    # Validate that required criteria are present
    def validate_criteria(*required_keys)
      missing_keys = required_keys.select { |key| criteria[key.to_s].blank? }
      return if missing_keys.empty?

      raise ArgumentError, "Missing required criteria: #{missing_keys.join(', ')}"
    end

    # Safe access to criteria values with defaults
    def criteria_value(key, default = nil)
      criteria[key.to_s].presence || default
    end
  end
end