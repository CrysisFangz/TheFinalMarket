class EscrowOperationsService
  def self.hold_funds(escrow_transaction)
    if escrow_transaction.escrow_wallet.hold_funds(escrow_transaction.amount)
      escrow_transaction.update(status: :held)
      notify_parties(escrow_transaction, "Funds held in escrow")
      true
    else
      escrow_transaction.errors.add(:base, "Insufficient funds")
      false
    end
  end

  def self.release_funds(escrow_transaction, admin_approved: false)
    # Idempotency check - prevent duplicate releases
    if escrow_transaction.released?
      Rails.logger.warn("[ESCROW] Attempted duplicate release for transaction #{escrow_transaction.id}")
      return true
    end

    return false unless can_release_funds?(escrow_transaction, admin_approved)

    # Verify sufficient balance before transfer
    unless escrow_transaction.escrow_wallet.balance >= escrow_transaction.amount
      escrow_transaction.errors.add(:base, "Insufficient escrow balance: expected #{escrow_transaction.amount}, found #{escrow_transaction.escrow_wallet.balance}")
      log_error(escrow_transaction, "Insufficient balance during release", { expected: escrow_transaction.amount, actual: escrow_transaction.escrow_wallet.balance })
      return false
    end

    escrow_transaction.transaction do
      escrow_transaction.receiver.escrow_wallet.receive_funds(escrow_transaction.amount)
      escrow_transaction.escrow_wallet.release_funds(escrow_transaction.amount)
      escrow_transaction.update!(status: :released, admin_approved_at: admin_approved ? Time.current : nil)
      notify_parties(escrow_transaction, "Funds released to seller")
      log_transaction_event(escrow_transaction, "Funds released", { amount: escrow_transaction.amount, admin_approved: admin_approved })
    end
    true
  rescue => e
    escrow_transaction.errors.add(:base, "Failed to release funds: #{e.message}")
    log_error(escrow_transaction, "Release failed", { error: e.message, backtrace: e.backtrace.first(5) })
    false
  end

  def self.refund(escrow_transaction, refund_amount = nil, admin_approved: false)
    # Idempotency check - prevent duplicate refunds
    if escrow_transaction.refunded? || (escrow_transaction.partially_refunded? && refund_amount.nil?)
      Rails.logger.warn("[ESCROW] Attempted duplicate refund for transaction #{escrow_transaction.id}")
      return true
    end

    return false unless can_refund?(escrow_transaction, admin_approved)

    refund_amount ||= escrow_transaction.amount

    # Validate refund amount
    if refund_amount <= 0 || refund_amount > escrow_transaction.amount
      escrow_transaction.errors.add(:base, "Invalid refund amount: #{refund_amount} (must be between 0 and #{escrow_transaction.amount})")
      return false
    end

    # Verify sufficient balance
    unless escrow_transaction.escrow_wallet.balance >= refund_amount
      escrow_transaction.errors.add(:base, "Insufficient escrow balance for refund: expected #{refund_amount}, found #{escrow_transaction.escrow_wallet.balance}")
      log_error(escrow_transaction, "Insufficient balance during refund", { expected: refund_amount, actual: escrow_transaction.escrow_wallet.balance })
      return false
    end

    escrow_transaction.transaction do
      escrow_transaction.sender.escrow_wallet.receive_funds(refund_amount)
      escrow_transaction.escrow_wallet.release_funds(refund_amount)

      if refund_amount == escrow_transaction.amount
        escrow_transaction.update!(status: :refunded)
      else
        escrow_transaction.update!(status: :partially_refunded, refunded_amount: refund_amount)
      end

      notify_parties(escrow_transaction, "Refund processed: #{refund_amount}")
      log_transaction_event(escrow_transaction, "Refund processed", { amount: refund_amount, admin_approved: admin_approved })
    end
    true
  rescue => e
    escrow_transaction.errors.add(:base, "Failed to process refund: #{e.message}")
    log_error(escrow_transaction, "Refund failed", { error: e.message, backtrace: e.backtrace.first(5) })
    false
  end

  private

  def self.can_release_funds?(escrow_transaction, admin_approved)
    return false unless escrow_transaction.held?
    return true if admin_approved
    return false if escrow_transaction.needs_admin_approval && !admin_approved
    true
  end

  def self.can_refund?(escrow_transaction, admin_approved)
    return false unless escrow_transaction.held? || escrow_transaction.disputed?
    return true if admin_approved
    return false if escrow_transaction.needs_admin_approval && !admin_approved
    true
  end

  def self.notify_parties(escrow_transaction, message)
    [escrow_transaction.sender, escrow_transaction.receiver].each do |user|
      EscrowNotificationService.notify(
        user: user,
        title: "Escrow Update",
        message: message,
        resource: escrow_transaction
      )
    end
  end

  def self.log_transaction_event(escrow_transaction, event, metadata = {})
    Rails.logger.info({
      event: "[ESCROW] #{event}",
      transaction_id: escrow_transaction.id,
      order_id: escrow_transaction.order_id,
      sender_id: escrow_transaction.sender_id,
      receiver_id: escrow_transaction.receiver_id,
      amount: escrow_transaction.amount,
      status: escrow_transaction.status,
      timestamp: Time.current,
      metadata: metadata
    }.to_json)
  end

  def self.log_error(escrow_transaction, error_type, details = {})
    Rails.logger.error({
      event: "[ESCROW ERROR] #{error_type}",
      transaction_id: escrow_transaction.id,
      order_id: escrow_transaction.order_id,
      details: details,
      timestamp: Time.current
    }.to_json)
  end
end