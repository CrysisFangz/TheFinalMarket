# =============================================================================
# Monitor Stuck Transactions Job - Adaptive Stuck Transaction Detection
# =============================================================================
# This job detects and handles stuck XRP transactions using adaptive
# timeout thresholds and escalation mechanisms for high reliability.

class MonitorStuckTransactionsJob < ApplicationJob
  queue_as :low_priority

  # Perform stuck transaction monitoring
  # @param transaction_id [Integer] The transaction ID to monitor
  def perform(transaction_id)
    transaction = XrpTransaction.find_by(id: transaction_id)
    return unless transaction

    if transaction.confirmations_expired?
      handle_stuck_transaction(transaction)
    else
      # Reschedule for later check
      self.class.perform_in(1.hour, transaction_id)
    end
  end

  private

  # Handle stuck transaction with escalation
  # @param transaction [XrpTransaction] The stuck transaction
  def handle_stuck_transaction(transaction)
    Rails.logger.warn("Transaction #{transaction.id} appears stuck")

    # Attempt recovery actions
    recovery_result = attempt_recovery(transaction)

    if recovery_result.success?
      Rails.logger.info("Recovery successful for transaction #{transaction.id}")
    else
      escalate_to_admin(transaction)
    end
  end

  # Attempt recovery for stuck transaction
  # @param transaction [XrpTransaction] The transaction
  # @return [Dry::Monads::Result] Success or Failure
  def attempt_recovery(transaction)
    # Force re-monitoring
    TransactionConfirmationService.monitor_confirmations(transaction)
  end

  # Escalate stuck transaction to admin
  # @param transaction [XrpTransaction] The transaction
  def escalate_to_admin(transaction)
    AlertService.stuck_transaction(transaction)
    # Mark as expired
    transaction.update!(status: :expired)
  end
end