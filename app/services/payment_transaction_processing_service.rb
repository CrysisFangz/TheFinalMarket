class PaymentTransactionProcessingService
  attr_reader :transaction

  def initialize(transaction)
    @transaction = transaction
  end

  def process_transaction
    Rails.logger.info("Processing payment transaction ID: #{transaction.id}, type: #{transaction.transaction_type}")

    begin
      case transaction.transaction_type.to_sym
      when :purchase
        process_purchase_transaction
      when :refund
        process_refund_transaction
      when :payout
        process_payout_transaction
      when :fee, :bond, :bond_refund
        # These types don't need async processing
        mark_as_completed
      else
        Rails.logger.error("Unknown transaction type: #{transaction.transaction_type}")
        mark_as_failed("Unknown transaction type: #{transaction.transaction_type}")
      end
    rescue => e
      Rails.logger.error("Failed to process payment transaction ID: #{transaction.id}. Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      mark_as_failed(e.message)
    end
  end

  def mark_as_completed
    Rails.logger.debug("Marking payment transaction ID: #{transaction.id} as completed")

    begin
      transaction.update!(status: :completed)
      Rails.logger.info("Successfully marked payment transaction ID: #{transaction.id} as completed")
    rescue => e
      Rails.logger.error("Failed to mark payment transaction ID: #{transaction.id} as completed. Error: #{e.message}")
    end
  end

  def mark_as_failed(error_message)
    Rails.logger.error("Marking payment transaction ID: #{transaction.id} as failed: #{error_message}")

    begin
      transaction.update!(status: :failed, error_message: error_message)
      Rails.logger.info("Successfully marked payment transaction ID: #{transaction.id} as failed")
    rescue => e
      Rails.logger.error("Failed to mark payment transaction ID: #{transaction.id} as failed. Error: #{e.message}")
    end
  end

  private

  def process_purchase_transaction
    Rails.logger.info("Enqueuing purchase processing job for transaction ID: #{transaction.id}")

    begin
      ProcessPurchaseJob.perform_later(transaction)
      transaction.update!(status: :processing)
      Rails.logger.info("Successfully enqueued purchase processing for transaction ID: #{transaction.id}")
    rescue => e
      Rails.logger.error("Failed to enqueue purchase processing for transaction ID: #{transaction.id}. Error: #{e.message}")
      raise e
    end
  end

  def process_refund_transaction
    Rails.logger.info("Enqueuing refund processing job for transaction ID: #{transaction.id}")

    begin
      ProcessRefundJob.perform_later(transaction)
      transaction.update!(status: :processing)
      Rails.logger.info("Successfully enqueued refund processing for transaction ID: #{transaction.id}")
    rescue => e
      Rails.logger.error("Failed to enqueue refund processing for transaction ID: #{transaction.id}. Error: #{e.message}")
      raise e
    end
  end

  def process_payout_transaction
    Rails.logger.info("Enqueuing payout processing job for transaction ID: #{transaction.id}")

    begin
      ProcessPayoutJob.perform_later(transaction)
      transaction.update!(status: :processing)
      Rails.logger.info("Successfully enqueued payout processing for transaction ID: #{transaction.id}")
    rescue => e
      Rails.logger.error("Failed to enqueue payout processing for transaction ID: #{transaction.id}. Error: #{e.message}")
      raise e
    end
  end
end