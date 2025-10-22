# frozen_string_literal: true

module Charity
  module ValueObjects
    # Immutable Value Object representing monetary values with sophisticated business logic
    class Money
      attr_reader :amount_cents, :currency

      # Supported currencies with metadata
      CURRENCIES = {
        usd: { symbol: '$', name: 'US Dollar', decimal_places: 2, locale: :en },
        eur: { symbol: '€', name: 'Euro', decimal_places: 2, locale: :en },
        gbp: { symbol: '£', name: 'British Pound', decimal_places: 2, locale: :en },
        cad: { symbol: 'C$', name: 'Canadian Dollar', decimal_places: 2, locale: :en },
        aud: { symbol: 'A$', name: 'Australian Dollar', decimal_places: 2, locale: :en },
        jpy: { symbol: '¥', name: 'Japanese Yen', decimal_places: 0, locale: :ja },
        btc: { symbol: '₿', name: 'Bitcoin', decimal_places: 8, locale: :en },
        eth: { symbol: 'Ξ', name: 'Ethereum', decimal_places: 8, locale: :en }
      }.freeze

      # Create a new Money instance
      # @param amount_cents [Integer] amount in smallest currency unit (cents)
      # @param currency [Symbol] currency code
      def initialize(amount_cents, currency = :usd)
        @amount_cents = amount_cents.to_i
        @currency = currency.to_sym

        raise ArgumentError, 'Invalid currency' unless valid_currency?
      end

      # Create Money from decimal amount
      # @param amount [Float, BigDecimal] decimal amount
      # @param currency [Symbol] currency code
      # @return [Money] new Money instance
      def self.from_decimal(amount, currency = :usd)
        decimal_places = CURRENCIES.dig(currency.to_sym, :decimal_places) || 2
        cents = (amount.to_f * (10**decimal_places)).round.to_i

        new(cents, currency)
      end

      # Create Money from string (e.g., "$1,234.56")
      # @param amount_str [String] formatted amount string
      # @return [Money] new Money instance
      def self.from_string(amount_str)
        # Extract numeric value and currency symbol
        currency = detect_currency_from_string(amount_str)
        numeric_str = extract_numeric_value(amount_str)

        from_decimal(numeric_str.to_f, currency)
      end

      # Zero value for currency
      # @param currency [Symbol] currency code
      # @return [Money] zero Money instance
      def self.zero(currency = :usd)
        new(0, currency)
      end

      # Convert to decimal representation
      # @return [BigDecimal] decimal amount
      def to_decimal
        decimal_places = CURRENCIES.dig(@currency, :decimal_places) || 2
        BigDecimal(@amount_cents) / BigDecimal(10**decimal_places)
      end

      # Convert to float (use with caution due to precision)
      # @return [Float] float amount
      def to_f
        to_decimal.to_f
      end

      # Format for display
      # @param locale [Symbol] locale for formatting
      # @return [String] formatted currency string
      def format(locale = nil)
        locale ||= CURRENCIES.dig(@currency, :locale) || :en
        decimal_places = CURRENCIES.dig(@currency, :decimal_places) || 2

        amount = to_decimal.round(decimal_places)
        symbol = CURRENCIES.dig(@currency, :symbol) || '$'

        case locale
        when :en
          "#{symbol}#{amount.to_fs(:currency)}"
        when :ja
          "#{amount.to_fs(:currency)}#{symbol}"
        else
          "#{symbol}#{amount}"
        end
      end

      # Arithmetic operations (returning new immutable instances)
      # @param other [Money] money to add
      # @return [Money] sum
      def add(other)
        raise ArgumentError, 'Currency mismatch' unless @currency == other.currency

        Money.new(@amount_cents + other.amount_cents, @currency)
      end

      # @param other [Money] money to subtract
      # @return [Money] difference
      def subtract(other)
        raise ArgumentError, 'Currency mismatch' unless @currency == other.currency

        Money.new(@amount_cents - other.amount_cents, @currency)
      end

      # @param multiplier [Numeric] multiplier value
      # @return [Money] scaled amount
      def multiply(multiplier)
        Money.new((@amount_cents * multiplier).round, @currency)
      end

      # @param divisor [Numeric] divisor value
      # @return [Money] divided amount
      def divide(divisor)
        Money.new((@amount_cents / divisor.to_f).round, @currency)
      end

      # Comparison operations
      # @param other [Money] money to compare
      # @return [Boolean] true if equal amounts
      def ==(other)
        return false unless other.is_a?(Money)

        @amount_cents == other.amount_cents && @currency == other.currency
      end

      # @param other [Money] money to compare
      # @return [Integer] -1, 0, or 1
      def <=>(other)
        raise ArgumentError, 'Currency mismatch' unless @currency == other.currency

        @amount_cents <=> other.amount_cents
      end

      # @param other [Money] money to compare
      # @return [Boolean] true if this money is greater
      def >(other)
        (self <=> other) == 1
      end

      # @param other [Money] money to compare
      # @return [Boolean] true if this money is less
      def <(other)
        (self <=> other) == -1
      end

      # Convert to different currency (simplified - would need exchange rate service)
      # @param target_currency [Symbol] target currency
      # @return [Money] converted amount
      def convert_to(target_currency)
        # This is a simplified implementation
        # In real system, would integrate with exchange rate service
        return Money.new(@amount_cents, target_currency) if @currency == target_currency

        # Placeholder conversion (1:1 ratio)
        Money.new(@amount_cents, target_currency)
      end

      # Check if amount is zero
      # @return [Boolean] true if zero
      def zero?
        @amount_cents.zero?
      end

      # Check if amount is positive
      # @return [Boolean] true if positive
      def positive?
        @amount_cents.positive?
      end

      # Check if amount is negative
      # @return [Boolean] true if negative
      def negative?
        @amount_cents.negative?
      end

      # Get currency symbol
      # @return [String] currency symbol
      def currency_symbol
        CURRENCIES.dig(@currency, :symbol) || '$'
      end

      # Get currency name
      # @return [String] currency name
      def currency_name
        CURRENCIES.dig(@currency, :name) || 'Unknown Currency'
      end

      # Serialize for JSON
      # @return [Hash] serializable hash
      def as_json
        {
          amount_cents: @amount_cents,
          currency: @currency,
          formatted: format
        }
      end

      # Hash for collections
      # @return [Integer] hash value
      def hash
        [@amount_cents, @currency].hash
      end

      private

      # Validate currency is supported
      # @return [Boolean] true if valid currency
      def valid_currency?
        CURRENCIES.key?(@currency)
      end

      # Detect currency from formatted string
      # @param amount_str [String] formatted amount string
      # @return [Symbol] detected currency
      def self.detect_currency_from_string(amount_str)
        symbol_map = CURRENCIES.transform_values { |config| config[:symbol] }
        symbol_map.each do |currency, symbol|
          return currency if amount_str.include?(symbol)
        end

        :usd # Default fallback
      end

      # Extract numeric value from formatted string
      # @param amount_str [String] formatted amount string
      # @return [String] extracted numeric value
      def self.extract_numeric_value(amount_str)
        # Remove currency symbols and extract digits with decimal point
        amount_str.gsub(/[^\d.]/, '')
      end
    end
  end
end