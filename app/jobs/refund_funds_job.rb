class RefundFundsJob < ApplicationJob
  queue_as :payments

  def perform(escrow_transaction, amount = nil)
    # Use the safe, idempotent refund method from the model
    # This method includes all safety checks, validations, and audit logging
    # If amount is nil, it will refund the full amount
    result = escrow_transaction.refund(amount)

    if result
      # Success - funds refunded or already refunded (idempotent)
      Rails.logger.info("[ESCROW JOB] Successfully processed refund for transaction #{escrow_transaction.id}")
      
      # Notify buyer if this was a new refund
      if escrow_transaction.status == 'refunded'
        NotificationService.notify(
          user: escrow_transaction.sender,
          title: "Refund Processed",
          body: "A refund has been processed to your account."
        )
      end
    else
      # Log errors and let the job retry
      error_messages = escrow_transaction.errors.full_messages.join(', ')
      Rails.logger.error("[ESCROW JOB ERROR] Failed to process refund for transaction #{escrow_transaction.id}: #{error_messages}")
      raise StandardError, "Failed to process refund: #{error_messages}"
    end
  end

  retry_on StandardError, wait: :exponentially_longer, attempts: 3
end