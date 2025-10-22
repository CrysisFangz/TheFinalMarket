# frozen_string_literal: true

module Charity
  module ValueObjects
    # Immutable Value Object representing an Employer Identification Number (EIN)
    # Provides sophisticated validation and formatting for US tax identification numbers
    class EIN
      # EIN format: XX-XXXXXXX (2 digits hyphen 7 digits)
      EIN_FORMAT = /\A\d{2}-\d{7}\z/.freeze

      attr_reader :value

      # Create a new EIN with validation
      # @param value [String] the EIN value
      # @raise [ArgumentError] if the EIN format is invalid
      def initialize(value)
        @value = normalize_ein(value)

        raise ArgumentError, 'Invalid EIN format' unless valid_format?
        raise ArgumentError, 'EIN failed checksum validation' unless valid_checksum?
      end

      # Create EIN from raw digits (for form input processing)
      # @param digits [String, Integer] 9 digits without formatting
      # @return [EIN] formatted EIN object
      def self.from_digits(digits)
        normalized = digits.to_s.gsub(/\D/, '')
        return new(normalized.insert(2, '-')) if normalized.length == 9

        raise ArgumentError, 'EIN must contain exactly 9 digits'
      end

      # Parse EIN from various string formats
      # @param input [String] potentially formatted EIN string
      # @return [EIN] validated EIN object
      def self.parse(input)
        return new(input) if input.match?(EIN_FORMAT)

        # Try to extract digits and format
        digits = input.gsub(/\D/, '')
        return from_digits(digits) if digits.length == 9

        raise ArgumentError, 'Cannot parse valid EIN from input'
      end

      # Format for display
      # @return [String] formatted EIN
      def to_s
        @value
      end

      # Get digits only (for API calls, comparisons)
      # @return [String] digits without formatting
      def digits_only
        @value.gsub('-', '')
      end

      # Format for JSON serialization
      # @return [String] formatted EIN for JSON
      def as_json
        @value
      end

      # Equality comparison
      # @param other [EIN] other EIN to compare
      # @return [Boolean] true if equal
      def ==(other)
        return false unless other.is_a?(EIN)

        digits_only == other.digits_only
      end

      # Hash for use in collections
      # @return [Integer] hash value
      def hash
        digits_only.hash
      end

      # Check if EIN is valid (format and checksum)
      # @return [Boolean] true if valid
      def valid?
        valid_format? && valid_checksum?
      end

      private

      # Normalize EIN input to standard format
      # @param input [String] raw EIN input
      # @return [String] normalized EIN
      def normalize_ein(input)
        return input if input.match?(EIN_FORMAT)

        # Remove all non-digits and format
        digits = input.gsub(/\D/, '')
        return digits.insert(2, '-') if digits.length == 9

        input
      end

      # Validate format using regex
      # @return [Boolean] true if format is valid
      def valid_format?
        @value.match?(EIN_FORMAT)
      end

      # Validate EIN using checksum algorithm
      # @return [Boolean] true if checksum is valid
      def valid_checksum?
        return true unless @value.match?(EIN_FORMAT)

        digits = @value.gsub('-', '').chars.map(&:to_i)

        # EIN checksum: (digit1*2 + digit2*3 + ... + digit8*9) mod 10 == digit9
        weights = [2, 3, 4, 5, 6, 7, 8, 9]
        weighted_sum = digits[0..7].zip(weights).sum { |digit, weight| digit * weight }

        (weighted_sum % 10) == digits[8]
      end
    end
  end
end