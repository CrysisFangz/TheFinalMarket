# frozen_string_literal: true

module Translation
  module ValueObjects
    # Value object representing a translation key
    class TranslationKey
      # @param key [String] the translation key
      def initialize(key)
        @key = key.to_s.strip
        validate!
      end

      # @return [String] the key
      def to_s
        @key
      end

      # @param other [TranslationKey] key to compare
      # @return [Boolean] true if keys are equal
      def ==(other)
        return false unless other.is_a?(TranslationKey)
        @key == other.to_s
      end

      # @return [Integer] hash code
      def hash
        @key.hash
      end

      private

      # Validates the key
      # @raise [ArgumentError] if invalid
      def validate!
        if @key.empty?
          raise ArgumentError, 'Translation key cannot be empty'
        end
        if @key.length > 255
          raise ArgumentError, 'Translation key cannot exceed 255 characters'
        end
      end
    end
  end
end