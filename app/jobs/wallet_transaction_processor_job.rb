# frozen_string_literal: true

# Background job for processing wallet transactions asynchronously to ensure scalability and non-blocking operations.
class WalletTransactionProcessorJob < ApplicationJob
  queue_as :default

  def perform(transaction_id)
    transaction = WalletTransaction.find(transaction_id)
    WalletTransactionService.process_transaction(transaction)
  rescue ActiveRecord::RecordNotFound
    # Log or handle missing transaction
  end
end