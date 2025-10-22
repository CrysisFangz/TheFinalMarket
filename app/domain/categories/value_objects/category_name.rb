# frozen_string_literal: true

module Categories
  module ValueObjects
    # Immutable value object representing a category name with business rules
    class CategoryName
      # Maximum length for category names
      MAX_LENGTH = 50
      # Minimum length for category names
      MIN_LENGTH = 2

      # @param value [String] the category name
      # @raise [ArgumentError] if value is invalid
      def initialize(value)
        @value = validate_and_normalize(value)
      end

      # @return [String] the normalized category name
      def to_s
        @value
      end

      # @return [String] string representation for serialization
      def to_str
        @value
      end

      # @param other [CategoryName] object to compare
      # @return [Boolean] true if names are equal
      def ==(other)
        return false unless other.is_a?(CategoryName)
        @value == other.to_s
      end

      # @return [Integer] hash code for the name
      def hash
        @value.hash
      end

      # @return [Boolean] true if name is valid
      def valid?
        !@value.nil? && @value.length >= MIN_LENGTH && @value.length <= MAX_LENGTH
      end

      # @return [String] the normalized name for database storage
      def for_storage
        @value
      end

      private

      # Validates and normalizes the category name
      # @param value [String] the input name
      # @return [String] normalized name
      # @raise [ArgumentError] if validation fails
      def validate_and_normalize(value)
        raise ArgumentError, 'Category name cannot be nil' if value.nil?
        raise ArgumentError, 'Category name cannot be empty' if value.strip.empty?

        normalized = value.strip

        unless normalized.length >= MIN_LENGTH
          raise ArgumentError, "Category name must be at least #{MIN_LENGTH} characters"
        end

        unless normalized.length <= MAX_LENGTH
          raise ArgumentError, "Category name cannot exceed #{MAX_LENGTH} characters"
        end

        # Check for invalid characters (only allow alphanumeric, spaces, hyphens, apostrophes)
        unless normalized.match?(/\A[a-zA-Z0-9\s\-']+\z/)
          raise ArgumentError, 'Category name contains invalid characters'
        end

        # Normalize to title case
        normalized.split.map(&:capitalize).join(' ')
      end
    end
  end
end