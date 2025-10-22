# =============================================================================
# Monitor XRP Confirmations Job - Asynchronous Confirmation Monitoring
# =============================================================================
# This job handles asynchronous monitoring of XRP transaction confirmations,
# integrating with the confirmation service for real-time updates and
# adaptive retry logic for resilient operation.

class MonitorXrpConfirmationsJob < ApplicationJob
  queue_as :default

  # Retry configuration for resilience
  retry_on StandardError, attempts: 5, wait: :exponentially_longer

  # Perform confirmation monitoring for a transaction
  # @param transaction_id [Integer] The transaction ID to monitor
  def perform(transaction_id)
    transaction = XrpTransaction.find_by(id: transaction_id)
    return unless transaction

    Rails.logger.info("Monitoring confirmations for transaction #{transaction_id}")

    result = TransactionConfirmationService.monitor_confirmations(transaction)

    if result.success?
      Rails.logger.info("Confirmation monitoring successful for transaction #{transaction_id}")
    else
      Rails.logger.error("Confirmation monitoring failed for transaction #{transaction_id}: #{result.failure}")
      # Schedule retry if needed
      retry_job(transaction_id) unless executions > 3
    end
  end

  private

  # Schedule retry for failed monitoring
  # @param transaction_id [Integer] The transaction ID
  def retry_job(transaction_id)
    self.class.perform_later(transaction_id)
  end
end