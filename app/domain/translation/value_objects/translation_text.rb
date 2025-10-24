# frozen_string_literal: true

module Translation
  module ValueObjects
    # Value object representing translation text
    class TranslationText
      MAX_LENGTH = 10_000

      # @param text [String] the translation text
      def initialize(text)
        @text = text.to_s
        validate!
      end

      # @return [String] the text
      def to_s
        @text
      end

      # @param other [TranslationText] text to compare
      # @return [Boolean] true if texts are equal
      def ==(other)
        return false unless other.is_a?(TranslationText)
        @text == other.to_s
      end

      # @return [Integer] hash code
      def hash
        @text.hash
      end

      # @return [Integer] length of the text
      def length
        @text.length
      end

      private

      # Validates the text
      # @raise [ArgumentError] if invalid
      def validate!
        if @text.length > MAX_LENGTH
          raise ArgumentError, "Translation text cannot exceed #{MAX_LENGTH} characters"
        end
      end
    end
  end
end