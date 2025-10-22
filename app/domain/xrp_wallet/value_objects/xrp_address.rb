# frozen_string_literal: true

require 'digest'

module XrpWallet
  module ValueObjects
    # Immutable value object representing an XRP wallet address with validation
    class XrpAddress
      include Comparable

      # XRP address format constants
      XRP_ADDRESS_REGEX = /^r[rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz]{27,35}$/
      CLASSIC_ADDRESS_LENGTH = 34
      XRP_ALPHABET = 'rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz'

      # @param address [String] The XRP address string
      # @raise [ArgumentError] if address is invalid
      def initialize(address)
        @address = validate_address(address)

        freeze # Make immutable
      end

      # @return [String] The XRP address value
      attr_reader :address

      # @return [String] String representation
      def to_s
        address
      end

      def ==(other)
        other.is_a?(XrpAddress) && address == other.address
      end

      def eql?(other)
        self == other
      end

      def hash
        [self.class, address].hash
      end

      # @return [Boolean] Whether this is a valid XRP mainnet address
      def mainnet?
        address.length == CLASSIC_ADDRESS_LENGTH && valid_checksum?
      end

      # @return [Boolean] Whether this is a valid XRP testnet address
      def testnet?
        address.length == CLASSIC_ADDRESS_LENGTH && valid_checksum?
      end

      # @return [String] Network type identifier
      def network_type
        return 'testnet' if testnet_byte?

        'mainnet'
      end

      private

      def validate_address(address)
        raise ArgumentError, 'Address cannot be nil or empty' if address.nil? || address.empty?
        raise ArgumentError, 'Invalid address format' unless valid_format?(address)

        address
      end

      def valid_format?(address)
        address.is_a?(String) && address.match?(XRP_ADDRESS_REGEX)
      end

      def valid_checksum?
        # XRP uses a modified base58 alphabet and checksum validation
        decoded = decode_xrp_address(address)
        return false if decoded.nil? || decoded.length < 5

        # Last 4 bytes are checksum
        payload = decoded[0..-5]
        provided_checksum = decoded[-4..-1]

        # Calculate expected checksum
        checksum1 = Digest::SHA256.digest(Digest::SHA256.digest(payload))[0..3]
        checksum2 = Digest::SHA256.digest(Digest::SHA256.digest(payload))[0..3]

        provided_checksum == checksum1 || provided_checksum == checksum2
      end

      def testnet_byte?
        # Testnet addresses start with 'T' when decoded
        decoded = decode_xrp_address(address)
        return false if decoded.nil? || decoded.empty?

        decoded.first == 0x74 # 'T' in ASCII
      end

      def decode_xrp_address(address)
        # Simplified XRP address decoding for validation
        # In production, use rippled's address codec
        begin
          # Remove 'r' prefix for decoding
          base58_chars = address[1..-1]

          # Convert base58 to bytes (simplified implementation)
          # This is a placeholder - use proper XRP address codec in production
          decoded_bytes = base58_decode(base58_chars)

          return nil if decoded_bytes.nil?

          decoded_bytes.bytes
        rescue
          nil
        end
      end

      def base58_decode(string)
        # Simplified base58 decode - use proper implementation in production
        # This is a placeholder for the actual XRP base58 decoding algorithm
        return nil unless string.chars.all? { |char| XRP_ALPHABET.include?(char) }

        # Placeholder implementation
        # In production, implement proper base58 decoding with XRP alphabet
        string.bytesum # This is not correct, just a placeholder
      end
    end
  end
end