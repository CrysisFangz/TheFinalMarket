# =============================================================================
# Transaction Cancellation Service - Rollback and Refund Engine
# =============================================================================
# This service handles transaction cancellation with ledger rollback,
# refund processing, and state management for failed or cancelled XRP transactions.

class TransactionCancellationService
  include Dry::Monads[:result]

  # Cancel transaction with rollback mechanism
  # @param transaction [XrpTransaction] The transaction to cancel
  # @param reason [String] Cancellation reason
  # @return [Dry::Monads::Result] Success or Failure
  def self.cancel_transaction(transaction, reason = nil)
    return Failure('Transaction must be provided') unless transaction.is_a?(XrpTransaction)
    return Failure('Transaction not cancellable') unless transaction.cancellable?

    # Attempt to cancel on ledger if not yet confirmed
    if transaction.submitted? && !transaction.confirmed?
      ledger_result = attempt_ledger_cancellation(transaction)
      return ledger_result unless ledger_result.success?
    end

    transaction.update!(
      status: :cancelled,
      cancelled_at: Time.current,
      cancellation_reason: reason
    )

    # Process cancellation refund if applicable
    process_cancellation_refund(transaction)

    Success(transaction)
  rescue StandardError => e
    Rails.logger.error("Cancellation failed for transaction #{transaction.id}: #{e.message}")
    Failure("Cancellation error: #{e.message}")
  end

  private

  # Attempt cancellation on the XRP ledger
  # @param transaction [XrpTransaction] The transaction
  # @return [Dry::Monads::Result] Success or Failure
  def self.attempt_ledger_cancellation(transaction)
    result = XrpLedgerService.cancel_transaction(
      transaction_hash: transaction.transaction_hash,
      account: transaction.source_wallet&.xrp_address
    )

    if result[:success]
      Success(result)
    else
      Failure(result[:error] || 'Ledger cancellation failed')
    end
  end

  # Process refund for cancelled transactions
  # @param transaction [XrpTransaction] The transaction
  def self.process_cancellation_refund(transaction)
    return unless transaction.transaction_type_outgoing_payment? && transaction.amount_xrp > 0

    # Create refund record
    XrpRefund.create!(
      original_transaction: transaction,
      refund_amount_xrp: transaction.amount_xrp,
      refund_address: transaction.source_wallet&.xrp_address,
      status: :pending
    )
  end
end