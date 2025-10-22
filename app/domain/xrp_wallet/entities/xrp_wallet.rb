# frozen_string_literal: true

require_relative '../value_objects/xrp_amount'
require_relative '../value_objects/xrp_address'
require_relative '../value_objects/transaction_hash'

module XrpWallet
  module Entities
    # Domain entity representing an XRP wallet with full business logic encapsulation
    class XrpWallet
      # Wallet status constants
      STATUSES = {
        active: 'active',
        suspended: 'suspended',
        locked: 'locked',
        closed: 'closed',
        pending_verification: 'pending_verification'
      }.freeze

      # XRP reserve requirements
      RESERVE_REQUIREMENTS = {
        base_reserve: XrpAmount.new(10),
        owner_reserve: XrpAmount.new(2)
      }.freeze

      # @param id [String] Unique wallet identifier
      # @param user_id [String] Associated user identifier
      # @param xrp_address [XrpAddress] XRP wallet address
      # @param status [String] Current wallet status
      # @param balance [XrpAmount] Current XRP balance
      # @param created_at [Time] Wallet creation timestamp
      # @param updated_at [Time] Last update timestamp
      def initialize(id:, user_id:, xrp_address:, status: STATUSES[:active], balance: XrpAmount.new(0), created_at: nil, updated_at: nil)
        @id = id
        @user_id = user_id
        @xrp_address = xrp_address.is_a?(XrpAddress) ? xrp_address : XrpAddress.new(xrp_address)
        @status = validate_status(status)
        @balance = balance.is_a?(XrpAmount) ? balance : XrpAmount.new(balance)
        @created_at = created_at || Time.current
        @updated_at = updated_at || Time.current

        validate_invariants
        freeze # Make immutable after validation
      end

      # @return [String] Unique wallet identifier
      attr_reader :id

      # @return [String] Associated user identifier
      attr_reader :user_id

      # @return [XrpAddress] XRP wallet address
      attr_reader :xrp_address

      # @return [String] Current wallet status
      attr_reader :status

      # @return [XrpAmount] Current XRP balance
      attr_reader :balance

      # @return [Time] Wallet creation timestamp
      attr_reader :created_at

      # @return [Time] Last update timestamp
      attr_reader :updated_at

      # Business logic methods

      # @param amount [XrpAmount] Amount to check for payment capability
      # @return [Boolean] Whether wallet can make payment
      def can_make_payment?(amount)
        return false unless active?
        return false unless amount.positive?

        required_reserve = calculate_required_reserve
        available_balance = balance - required_reserve

        available_balance >= amount
      end

      # @param amount [XrpAmount] Amount to check for reserve compliance
      # @return [Boolean] Whether wallet maintains required reserve after transaction
      def maintains_reserve_after?(amount)
        required_reserve = calculate_required_reserve
        remaining_balance = balance - amount

        remaining_balance >= required_reserve
      end

      # @return [Boolean] Whether wallet is in active state
      def active?
        status == STATUSES[:active]
      end

      # @return [Boolean] Whether wallet is locked
      def locked?
        status == STATUSES[:locked]
      end

      # @return [Boolean] Whether wallet is suspended
      def suspended?
        status == STATUSES[:suspended]
      end

      # @return [Boolean] Whether wallet is closed
      def closed?
        status == STATUSES[:closed]
      end

      # @return [Boolean] Whether wallet is operational (active and not locked/suspended)
      def operational?
        active? && !locked? && !suspended?
      end

      # @return [XrpAmount] Required reserve amount for this wallet
      def calculate_required_reserve
        RESERVE_REQUIREMENTS[:base_reserve]
      end

      # @return [XrpAmount] Available balance after reserve requirements
      def available_balance
        required_reserve = calculate_required_reserve
        return XrpAmount.new(0) if balance < required_reserve

        balance - required_reserve
      end

      # @return [Hash] Wallet state for serialization
      def to_h
        {
          id: id,
          user_id: user_id,
          xrp_address: xrp_address.to_s,
          status: status,
          balance: balance.to_s,
          available_balance: available_balance.to_s,
          created_at: created_at,
          updated_at: updated_at
        }
      end

      # Equality based on identity
      def ==(other)
        other.is_a?(XrpWallet) && id == other.id
      end

      def eql?(other)
        self == other
      end

      def hash
        [self.class, id].hash
      end

      private

      def validate_status(status)
        return status if STATUSES.value?(status)

        raise ArgumentError, "Invalid wallet status: #{status}. Must be one of: #{STATUSES.values}"
      end

      def validate_invariants
        raise ArgumentError, 'Wallet ID cannot be nil or empty' if id.nil? || id.empty?
        raise ArgumentError, 'User ID cannot be nil or empty' if user_id.nil? || user_id.empty?
        raise ArgumentError, 'Balance cannot be negative' if balance.negative?
        raise ArgumentError, 'Wallet must maintain minimum reserve' unless maintains_reserve_after?(XrpAmount.new(0))
      end
    end
  end
end