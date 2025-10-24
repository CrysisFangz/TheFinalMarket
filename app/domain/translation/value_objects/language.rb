# frozen_string_literal: true

module Translation
  module ValueObjects
    # Value object representing a language code
    class Language
      VALID_LANGUAGES = %w[en es fr de it pt ru ja ko zh ar hi th vi nl sv da no fi pl tr he cs hu el bg hr sk sl et lv lt mt ga cy eu gl ca oc].freeze

      # @param code [String] language code (e.g., 'en', 'es')
      def initialize(code)
        @code = code.to_s.downcase
        validate!
      end

      # @return [String] language code
      def to_s
        @code
      end

      # @return [String] uppercase language code
      def upcase
        @code.upcase
      end

      # @param other [Language] language to compare
      # @return [Boolean] true if languages are equal
      def ==(other)
        return false unless other.is_a?(Language)
        @code == other.to_s
      end

      # @return [Integer] hash code
      def hash
        @code.hash
      end

      private

      # Validates the language code
      # @raise [ArgumentError] if invalid
      def validate!
        unless VALID_LANGUAGES.include?(@code)
          raise ArgumentError, "Invalid language code: #{@code}. Supported: #{VALID_LANGUAGES.join(', ')}"
        end
      end
    end
  end
end