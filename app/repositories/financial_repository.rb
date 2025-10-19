# frozen_string_literal: true

require 'singleton'

# FinancialRepository provides data access abstraction for financial entities
# Implements Repository pattern for loose coupling and testability
#
# @abstract
class FinancialRepository
  include Singleton

  # Payment transaction data access interface
  # @abstract
  class PaymentTransactionRepository
    include Singleton

    # Calculate total revenue from successful payments
    # @param start_date [DateTime, nil] Start date filter
    # @param end_date [DateTime, nil] End date filter
    # @return [Integer] Total amount in cents
    def total_revenue(start_date: nil, end_date: nil)
      raise NotImplementedError, 'Subclasses must implement total_revenue'
    end

    # Count successful transactions
    # @param start_date [DateTime, nil] Start date filter
    # @param end_date [DateTime, nil] End date filter
    # @return [Integer] Transaction count
    def successful_count(start_date: nil, end_date: nil)
      raise NotImplementedError, 'Subclasses must implement successful_count'
    end
  end

  # Escrow transaction data access interface
  # @abstract
  class EscrowTransactionRepository
    include Singleton

    # Calculate fees collected from released escrows
    # @param start_date [DateTime, nil] Start date filter
    # @param end_date [DateTime, nil] End date filter
    # @return [Integer] Total fees in cents
    def fees_collected(start_date: nil, end_date: nil)
      raise NotImplementedError, 'Subclasses must implement fees_collected'
    end

    # Calculate pending escrow amount
    # @param start_date [DateTime, nil] Start date filter
    # @param end_date [DateTime, nil] End date filter
    # @return [Integer] Total pending amount in cents
    def pending_amount(start_date: nil, end_date: nil)
      raise NotImplementedError, 'Subclasses must implement pending_amount'
    end
  end

  # Order data access interface
  # @abstract
  class OrderRepository
    include Singleton

    # Calculate total volume from completed orders
    # @param start_date [DateTime, nil] Start date filter
    # @param end_date [DateTime, nil] End date filter
    # @return [Integer] Total volume in cents
    def total_volume(start_date: nil, end_date: nil)
      raise NotImplementedError, 'Subclasses must implement total_volume'
    end
  end

  # Bond data access interface
  # @abstract
  class BondRepository
    include Singleton

    # Calculate active bonds amount
    # @param start_date [DateTime, nil] Start date filter
    # @param end_date [DateTime, nil] End date filter
    # @return [Integer] Total active amount in cents
    def active_amount(start_date: nil, end_date: nil)
      raise NotImplementedError, 'Subclasses must implement active_amount'
    end
  end

  # Get repository instances
  # @return [Hash] Repository instances
  def self.repositories
    @repositories ||= {
      payment_transaction: PaymentTransactionRepository.instance,
      escrow_transaction: EscrowTransactionRepository.instance,
      order: OrderRepository.instance,
      bond: BondRepository.instance
    }
  end

  private

  # Initialize concrete repositories
  def initialize_repositories
    @payment_transaction_repo ||= ActiveRecordPaymentTransactionRepository.new
    @escrow_transaction_repo ||= ActiveRecordEscrowTransactionRepository.new
    @order_repo ||= ActiveRecordOrderRepository.new
    @bond_repo ||= ActiveRecordBondRepository.new
  end

  attr_reader :payment_transaction_repo, :escrow_transaction_repo, :order_repo, :bond_repo
end