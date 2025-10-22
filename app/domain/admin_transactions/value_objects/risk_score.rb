# frozen_string_literal: true

module AdminTransactions
  module ValueObjects
    # Immutable value object representing calculated risk scores
    # Provides sophisticated risk assessment with confidence intervals
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class RiskScore
      # Risk level classifications with thresholds
      RISK_LEVELS = {
        negligible: { min: 0.0, max: 0.1, severity: :info, color: :green },
        low: { min: 0.1, max: 0.3, severity: :low, color: :blue },
        medium: { min: 0.3, max: 0.6, severity: :medium, color: :yellow },
        high: { min: 0.6, max: 0.8, severity: :high, color: :orange },
        critical: { min: 0.8, max: 1.0, severity: :critical, color: :red }
      }.freeze

      # @param value [Float] the risk score between 0.0 and 1.0
      # @param confidence [Float] confidence level between 0.0 and 1.0
      # @raise [ArgumentError] if values are invalid
      def initialize(value, confidence = 1.0)
        raise ArgumentError, 'Risk score must be between 0.0 and 1.0' unless valid_score?(value)
        raise ArgumentError, 'Confidence must be between 0.0 and 1.0' unless valid_confidence?(confidence)

        @value = value.to_f.freeze
        @confidence = confidence.to_f.freeze
        @calculated_at = Time.current.freeze
      end

      # @return [Float] the immutable risk score value
      attr_reader :value, :confidence, :calculated_at

      # @return [Symbol] the risk level classification
      def level
        RISK_LEVELS.find { |_, range| @value.between?(range[:min], range[:max]) }&.first || :unknown
      end

      # @return [Hash] metadata for the current risk level
      def level_metadata
        RISK_LEVELS[level] || {}
      end

      # @return [Symbol] the severity level
      def severity
        level_metadata[:severity] || :unknown
      end

      # @return [Symbol] the color code for UI representation
      def color
        level_metadata[:color] || :gray
      end

      # @return [Boolean] true if risk is considered high or critical
      def high_risk?
        [:high, :critical].include?(level)
      end

      # @return [Boolean] true if risk is considered critical
      def critical_risk?
        level == :critical
      end

      # @return [Boolean] true if risk is considered low or negligible
      def low_risk?
        [:negligible, :low].include?(level)
      end

      # @return [Float] weighted score considering confidence
      def weighted_score
        @value * @confidence
      end

      # @param threshold [Float] threshold to compare against
      # @return [Boolean] true if score exceeds threshold
      def exceeds?(threshold)
        raise ArgumentError, 'Threshold must be between 0.0 and 1.0' unless valid_score?(threshold)

        @value > threshold
      end

      # @param other [RiskScore] score to compare
      # @return [Integer] comparison result (-1, 0, 1)
      def <=>(other)
        raise ArgumentError, 'Can only compare RiskScore objects' unless other.is_a?(RiskScore)

        @value <=> other.value
      end

      # @param other [RiskScore] object to compare
      # @return [Boolean] true if values are equal within tolerance
      def ==(other)
        return false unless other.is_a?(RiskScore)

        (@value - other.value).abs < 0.001
      end
      alias eql? ==

      # @return [Integer] hash code for use in collections
      def hash
        [@value, @confidence].hash
      end

      # @return [String] formatted risk score string
      def to_s
        "#{(value * 100).round(2)}% (#{level.to_s.titleize})"
      end

      # @return [Hash] JSON-serializable representation
      def as_json
        {
          value: @value,
          confidence: @confidence,
          level: level,
          severity: severity,
          color: color,
          high_risk: high_risk?,
          critical_risk: critical_risk?,
          calculated_at: @calculated_at,
          formatted: to_s
        }
      end

      # @return [String] inspection string for debugging
      def inspect
        "RiskScore(#{value} - #{level})"
      end

      private

      # Validates risk score is within acceptable range
      # @param score [Float] the score to validate
      # @return [Boolean] true if score is valid
      def valid_score?(score)
        score.between?(0.0, 1.0)
      end

      # Validates confidence level is within acceptable range
      # @param confidence [Float] the confidence to validate
      # @return [Boolean] true if confidence is valid
      def valid_confidence?(confidence)
        confidence.between?(0.0, 1.0)
      end
    end
  end
end