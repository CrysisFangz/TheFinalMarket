# frozen_string_literal: true

module Categories
  module ValueObjects
    # Immutable value object representing category status with business rules
    class CategoryStatus
      # Valid status values
      ACTIVE = :active
      INACTIVE = :inactive
      PENDING = :pending

      VALID_STATUSES = [ACTIVE, INACTIVE, PENDING].freeze

      # @param status [Symbol] the category status
      # @raise [ArgumentError] if status is invalid
      def initialize(status)
        @status = validate_status(status)
      end

      # @return [Symbol] the status value
      def to_sym
        @status
      end

      # @return [String] string representation
      def to_s
        @status.to_s
      end

      # @return [Boolean] true if category is active
      def active?
        @status == ACTIVE
      end

      # @return [Boolean] true if category is inactive
      def inactive?
        @status == INACTIVE
      end

      # @return [Boolean] true if category is pending
      def pending?
        @status == PENDING
      end

      # @return [Boolean] true if category can be used for new items
      def usable?
        active?
      end

      # @return [Boolean] true if category can be displayed to users
      def displayable?
        active? || pending?
      end

      # @param other [CategoryStatus] status to compare
      # @return [Boolean] true if statuses are equal
      def ==(other)
        return false unless other.is_a?(CategoryStatus)
        @status == other.to_sym
      end

      # @return [Integer] hash code for the status
      def hash
        @status.hash
      end

      # @return [String] string representation for database storage
      def for_storage
        @status.to_s
      end

      # @return [Array<CategoryStatus>] all valid statuses
      def self.all
        VALID_STATUSES.map { |status| new(status) }
      end

      private

      # Validates the status value
      # @param status [Symbol] the status to validate
      # @return [Symbol] the validated status
      # @raise [ArgumentError] if status is invalid
      def validate_status(status)
        unless status.is_a?(Symbol)
          raise ArgumentError, 'Status must be a symbol'
        end

        unless VALID_STATUSES.include?(status)
          raise ArgumentError, "Invalid status: #{status}. Must be one of: #{VALID_STATUSES.join(', ')}"
        end

        status
      end
    end
  end
end