class ReleaseFundsJob < ApplicationJob
  queue_as :payments

  def perform(escrow_transaction, admin_approved: false)
    # Use the safe, idempotent release_funds method from the model
    # This method includes all safety checks, validations, and audit logging
    result = escrow_transaction.release_funds(admin_approved: admin_approved)

    if result
      # Success - funds released or already released (idempotent)
      Rails.logger.info("[ESCROW JOB] Successfully released funds for transaction #{escrow_transaction.id}")
      
      # Notify seller if this was a new release
      if escrow_transaction.status == 'released'
        NotificationService.notify(
          user: escrow_transaction.receiver,
          title: "Payment Released",
          body: "Payment has been released to your account."
        )
      end
    else
      # Log errors and let the job retry
      error_messages = escrow_transaction.errors.full_messages.join(', ')
      Rails.logger.error("[ESCROW JOB ERROR] Failed to release funds for transaction #{escrow_transaction.id}: #{error_messages}")
      raise StandardError, "Failed to release funds: #{error_messages}"
    end
  end

  retry_on StandardError, wait: :exponentially_longer, attempts: 3
end