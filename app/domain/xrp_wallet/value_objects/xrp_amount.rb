# frozen_string_literal: true

module XrpWallet
  module ValueObjects
    # Immutable value object representing XRP amount with precision handling
    class XrpAmount
      include Comparable

      # XRP precision constants
      XRP_PRECISION = 6
      MINIMUM_AMOUNT = BigDecimal('0.000001') # Minimum XRP amount for transactions
      MAXIMUM_AMOUNT = BigDecimal('100000000') # Maximum practical XRP amount

      # @param amount [Numeric, String, BigDecimal] The XRP amount value
      # @raise [ArgumentError] if amount is invalid
      def initialize(amount)
        @amount = validate_and_normalize(amount)

        freeze # Make immutable
      end

      # @return [BigDecimal] The XRP amount value
      attr_reader :amount

      # @return [String] String representation with proper precision
      def to_s
        amount.to_s('F')
      end

      # @return [Float] Float representation for API compatibility
      def to_f
        amount.to_f
      end

      # Comparison operators for value object behavior
      def <=>(other)
        return nil unless other.is_a?(XrpAmount)

        amount <=> other.amount
      end

      def ==(other)
        other.is_a?(XrpAmount) && amount == other.amount
      end

      def eql?(other)
        self == other
      end

      def hash
        [self.class, amount].hash
      end

      # Arithmetic operations returning new instances
      def +(other)
        self.class.new(amount + other.amount)
      end

      def -(other)
        self.class.new(amount - other.amount)
      end

      def *(multiplier)
        self.class.new(amount * multiplier)
      end

      def /(divisor)
        self.class.new(amount / divisor)
      end

      # Validation methods
      def valid_for_transaction?
        amount >= MINIMUM_AMOUNT && amount <= MAXIMUM_AMOUNT
      end

      def sufficient_reserve?(required_reserve)
        amount >= required_reserve
      end

      def zero?
        amount.zero?
      end

      def positive?
        amount.positive?
      end

      private

      def validate_and_normalize(amount)
        normalized = case amount
                     when String
                       BigDecimal(amount)
                     when Numeric
                       BigDecimal(amount.to_s)
                     else
                       BigDecimal(amount.to_s)
                     end

        raise ArgumentError, 'Amount must be a valid number' unless valid_big_decimal?(normalized)
        raise ArgumentError, 'Amount cannot be negative' if normalized.negative?
        raise ArgumentError, 'Amount exceeds maximum allowed' if normalized > MAXIMUM_AMOUNT

        # Round to XRP precision
        normalized.round(XRP_PRECISION)
      end

      def valid_big_decimal?(value)
        !value.nil? && !value.nan? && !value.infinite?
      end
    end
  end
end