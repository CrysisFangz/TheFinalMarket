# frozen_string_literal: true

module XrpWallet
  module Infrastructure
    # Comprehensive error hierarchy for XRP wallet operations
    module Errors
      # Base error class for all XRP wallet errors
      class XrpWalletError < StandardError
        # @param message [String] Error message
        # @param cause [Exception, nil] Underlying cause
        def initialize(message, cause = nil)
          super(message)
          @cause = cause
        end

        # @return [Exception, nil] Underlying cause
        attr_reader :cause
      end

      # Validation errors
      class ValidationError < XrpWalletError
        # @param field [String] Field that failed validation
        # @param value [Object] Invalid value
        # @param reason [String] Reason for validation failure
        def initialize(field:, value:, reason:)
          super("Validation failed for #{field}: #{reason}")
          @field = field
          @value = value
          @reason = reason
        end

        # @return [String] Field that failed validation
        attr_reader :field

        # @return [Object] Invalid value
        attr_reader :value

        # @return [String] Reason for validation failure
        attr_reader :reason
      end

      # Invalid amount error
      class InvalidAmountError < ValidationError
        def initialize(amount)
          super(field: :amount, value: amount, reason: 'Amount must be positive and within limits')
        end
      end

      # Invalid address error
      class InvalidAddressError < ValidationError
        def initialize(address)
          super(field: :address, value: address, reason: 'Invalid XRP address format')
        end
      end

      # Insufficient funds error
      class InsufficientFundsError < XrpWalletError
        def initialize(required:, available:)
          super("Insufficient funds: required #{required}, available #{available}")
          @required = required
          @available = available
        end

        # @return [BigDecimal] Required amount
        attr_reader :required

        # @return [BigDecimal] Available amount
        attr_reader :available
      end

      # Insufficient reserve error
      class InsufficientReserveError < XrpWalletError
        def initialize(required_reserve:, current_balance:)
          super("Insufficient reserve: required #{required_reserve}, current #{current_balance}")
          @required_reserve = required_reserve
          @current_balance = current_balance
        end

        # @return [BigDecimal] Required reserve amount
        attr_reader :required_reserve

        # @return [BigDecimal] Current balance
        attr_reader :current_balance
      end

      # Transaction errors
      class TransactionError < XrpWalletError
        def initialize(transaction_id:, reason:)
          super("Transaction #{transaction_id} failed: #{reason}")
          @transaction_id = transaction_id
          @reason = reason
        end

        # @return [String] Transaction identifier
        attr_reader :transaction_id

        # @return [String] Failure reason
        attr_reader :reason
      end

      # Invalid transaction error
      class InvalidTransactionError < TransactionError
        def initialize(transaction_hash)
          super(transaction_id: transaction_hash, reason: 'Transaction not found or invalid')
        end
      end

      # Amount mismatch error
      class AmountMismatchError < TransactionError
        def initialize(expected:, actual:)
          super(
            transaction_id: 'unknown',
            reason: "Amount mismatch: expected #{expected}, got #{actual}"
          )
          @expected = expected
          @actual = actual
        end

        # @return [BigDecimal] Expected amount
        attr_reader :expected

        # @return [BigDecimal] Actual amount
        attr_reader :actual
      end

      # Destination mismatch error
      class DestinationMismatchError < TransactionError
        def initialize(expected:, actual:)
          super(
            transaction_id: 'unknown',
            reason: "Destination mismatch: expected #{expected}, got #{actual}"
          )
          @expected = expected
          @actual = actual
        end

        # @return [String] Expected destination
        attr_reader :expected

        # @return [String] Actual destination
        attr_reader :actual
      end

      # Network errors
      class NetworkError < XrpWalletError
        def initialize(operation:, reason:)
          super("Network error during #{operation}: #{reason}")
          @operation = operation
          @reason = reason
        end

        # @return [String] Network operation that failed
        attr_reader :operation

        # @return [String] Failure reason
        attr_reader :reason
      end

      # Ledger errors
      class LedgerError < XrpWalletError
        def initialize(operation:, ledger_index:, reason:)
          super("Ledger error during #{operation} at index #{ledger_index}: #{reason}")
          @operation = operation
          @ledger_index = ledger_index
          @reason = reason
        end

        # @return [String] Ledger operation that failed
        attr_reader :operation

        # @return [Integer] Ledger index where error occurred
        attr_reader :ledger_index

        # @return [String] Failure reason
        attr_reader :reason
      end

      # Security errors
      class SecurityError < XrpWalletError
        def initialize(violation:, details:)
          super("Security violation: #{violation} - #{details}")
          @violation = violation
          @details = details
        end

        # @return [String] Security violation type
        attr_reader :violation

        # @return [String] Violation details
        attr_reader :details
      end

      # Rate limiting errors
      class RateLimitError < XrpWalletError
        def initialize(limit:, window:)
          super("Rate limit exceeded: #{limit} requests per #{window} seconds")
          @limit = limit
          @window = window
        end

        # @return [Integer] Rate limit
        attr_reader :limit

        # @return [Integer] Time window in seconds
        attr_reader :window
      end

      # Configuration errors
      class ConfigurationError < XrpWalletError
        def initialize(setting:, reason:)
          super("Configuration error for #{setting}: #{reason}")
          @setting = setting
          @reason = reason
        end

        # @return [String] Configuration setting
        attr_reader :setting

        # @return [String] Configuration error reason
        attr_reader :reason
      end
    end
  end
end