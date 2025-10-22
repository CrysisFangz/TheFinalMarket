# frozen_string_literal: true

module XrpWallet
  module ValueObjects
    # Immutable value object representing an XRP transaction hash
    class TransactionHash
      include Comparable

      # XRP transaction hash format constants
      HASH_REGEX = /^[A-F0-9]{64}$/i
      HASH_LENGTH = 64

      # @param hash [String] The transaction hash string
      # @raise [ArgumentError] if hash is invalid
      def initialize(hash)
        @hash = validate_hash(hash)

        freeze # Make immutable
      end

      # @return [String] The transaction hash value
      attr_reader :hash

      # @return [String] String representation
      def to_s
        hash
      end

      def ==(other)
        other.is_a?(TransactionHash) && hash == other.hash
      end

      def eql?(other)
        self == other
      end

      def hash
        [self.class, @hash].hash
      end

      # @return [Boolean] Whether this is a valid XRP transaction hash format
      def valid_format?
        hash.match?(HASH_REGEX)
      end

      private

      def validate_hash(hash)
        raise ArgumentError, 'Transaction hash cannot be nil or empty' if hash.nil? || hash.empty?
        raise ArgumentError, 'Invalid transaction hash format' unless valid_format?

        hash.upcase
      end
    end
  end
end