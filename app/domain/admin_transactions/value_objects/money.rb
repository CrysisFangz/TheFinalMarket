# frozen_string_literal: true

require 'money'

module AdminTransactions
  module ValueObjects
    # Immutable value object representing monetary amounts with currency
    # Provides type-safe financial calculations and formatting
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class Money
      # @param amount [BigDecimal, Integer, Float, String] the monetary amount
      # @param currency [String] the ISO currency code
      # @raise [ArgumentError] if amount or currency is invalid
      def initialize(amount, currency = 'USD')
        raise ArgumentError, 'Amount cannot be blank' if amount.blank?
        raise ArgumentError, 'Currency cannot be blank' if currency.blank?

        @amount = parse_amount(amount)
        @currency = Money::Currency.new(currency.upcase)

        validate_amount_range
      rescue Money::Currency::UnknownCurrency => e
        raise ArgumentError, "Invalid currency: #{currency}"
      end

      # @return [BigDecimal] the immutable amount value
      attr_reader :amount

      # @return [Money::Currency] the currency object
      attr_reader :currency

      # @param other [Money] object to add
      # @return [Money] new Money object with summed amount
      def +(other)
        raise ArgumentError, 'Can only add Money objects' unless other.is_a?(Money)
        raise ArgumentError, 'Currencies must match' unless currency == other.currency

        Money.new(amount + other.amount, currency.iso_code)
      end

      # @param other [Money] object to subtract
      # @return [Money] new Money object with subtracted amount
      def -(other)
        raise ArgumentError, 'Can only subtract Money objects' unless other.is_a?(Money)
        raise ArgumentError, 'Currencies must match' unless currency == other.currency

        Money.new(amount - other.amount, currency.iso_code)
      end

      # @param multiplier [Numeric] value to multiply by
      # @return [Money] new Money object with multiplied amount
      def *(multiplier)
        raise ArgumentError, 'Multiplier must be numeric' unless multiplier.is_a?(Numeric)

        Money.new(amount * multiplier, currency.iso_code)
      end

      # @param other [Money, Numeric] object to compare
      # @return [Integer] -1, 0, or 1 for less than, equal, or greater than
      def <=>(other)
        if other.is_a?(Money)
          raise ArgumentError, 'Currencies must match' unless currency == other.currency
          amount <=> other.amount
        elsif other.is_a?(Numeric)
          amount <=> other
        else
          raise ArgumentError, 'Can only compare with Money or Numeric'
        end
      end

      # @param other [Money, Numeric] object to compare
      # @return [Boolean] true if amounts are equal
      def ==(other)
        (self <=> other).zero?
      rescue ArgumentError
        false
      end
      alias eql? ==

      # @return [Boolean] true if amount is greater than zero
      def positive?
        amount.positive?
      end

      # @return [Boolean] true if amount is zero or greater
      def non_negative?
        amount >= 0
      end

      # @return [Boolean] true if amount is zero
      def zero?
        amount.zero?
      end

      # @return [Integer] hash code for use in collections
      def hash
        [amount, currency].hash
      end

      # @return [String] formatted currency string
      def to_s
        "#{amount.to_f} #{currency.iso_code}"
      end

      # @return [String] formatted currency with symbol
      def format
        "#{currency.symbol}#{amount.to_f}"
      end

      # @return [Hash] JSON-serializable representation
      def as_json
        {
          amount: amount.to_f,
          currency: currency.iso_code,
          formatted: format
        }
      end

      # @return [String] inspection string for debugging
      def inspect
        "Money(#{amount} #{currency.iso_code})"
      end

      private

      # Parses amount into BigDecimal for precision
      # @param amount [BigDecimal, Integer, Float, String] the amount to parse
      # @return [BigDecimal] parsed amount with precision
      def parse_amount(amount)
        case amount
        when BigDecimal
          amount
        when Integer, Float
          BigDecimal(amount.to_s, 10)
        when String
          BigDecimal(amount.gsub(/[^\d.-]/, ''), 10)
        else
          raise ArgumentError, "Unsupported amount type: #{amount.class}"
        end
      end

      # Validates amount is within acceptable range
      def validate_amount_range
        return if amount.between?(-999_999_999.99, 999_999_999.99)

        raise ArgumentError, 'Amount exceeds maximum allowed value'
      end
    end
  end
end