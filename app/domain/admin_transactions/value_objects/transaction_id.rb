# frozen_string_literal: true

module AdminTransactions
  module ValueObjects
    # Immutable value object representing a unique transaction identifier
    # Provides type safety and ensures transaction identity integrity
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class TransactionId
      # @param value [String] the unique identifier value
      # @raise [ArgumentError] if value is invalid
      def initialize(value)
        raise ArgumentError, 'Transaction ID cannot be blank' if value.blank?
        raise ArgumentError, 'Transaction ID must be alphanumeric' unless valid_format?(value)

        @value = value.dup.freeze
      end

      # @return [String] the immutable identifier value
      attr_reader :value

      # @param other [TransactionId] object to compare
      # @return [Boolean] true if values are equal
      def ==(other)
        return false unless other.is_a?(TransactionId)

        value == other.value
      end
      alias eql? ==

      # @return [Integer] hash code for use in collections
      def hash
        value.hash
      end

      # @return [String] string representation of the transaction ID
      def to_s
        value
      end

      # @return [String] inspection string for debugging
      def inspect
        "TransactionId(#{value})"
      end

      private

      # Validates the format of the transaction ID
      # @param value [String] the value to validate
      # @return [Boolean] true if format is valid
      def valid_format?(value)
        value.match?(/\A[A-Z0-9]{8,32}\z/)
      end
    end
  end
end