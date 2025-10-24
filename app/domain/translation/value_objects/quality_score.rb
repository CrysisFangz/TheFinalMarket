# frozen_string_literal: true

module Translation
  module ValueObjects
    # Value object representing a translation quality score
    class QualityScore
      MIN_SCORE = 0
      MAX_SCORE = 100

      # @param score [Integer] quality score (0-100)
      def initialize(score)
        @score = score.to_i
        validate!
      end

      # @return [Integer] the score
      def to_i
        @score
      end

      # @return [Float] the score as float
      def to_f
        @score.to_f
      end

      # @return [String] the score as string
      def to_s
        @score.to_s
      end

      # @return [Boolean] true if verified (score == 100)
      def verified?
        @score == MAX_SCORE
      end

      # @param other [QualityScore] score to compare
      # @return [Boolean] true if scores are equal
      def ==(other)
        return false unless other.is_a?(QualityScore)
        @score == other.to_i
      end

      # @return [Integer] hash code
      def hash
        @score.hash
      end

      private

      # Validates the score
      # @raise [ArgumentError] if invalid
      def validate!
        unless (@score >= MIN_SCORE && @score <= MAX_SCORE)
          raise ArgumentError, "Quality score must be between #{MIN_SCORE} and #{MAX_SCORE}, got #{@score}"
        end
      end
    end
  end
end