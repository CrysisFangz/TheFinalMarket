class EscrowTransaction < ApplicationRecord
  belongs_to :escrow_wallet
  belongs_to :order
  belongs_to :sender, class_name: 'User'
  belongs_to :receiver, class_name: 'User'

  enum status: {
    pending: 0,
    held: 1,
    released: 2,
    refunded: 3,
    disputed: 4,
    partially_refunded: 5
  }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :transaction_type, presence: true
  validate :sender_and_receiver_different
  validate :release_date_in_future, if: -> { scheduled_release_at.present? }

  scope :pending_finalization, -> { where(status: :held).where('created_at <= ?', 7.days.ago) }
  scope :needs_admin_approval, -> { where(status: :held, needs_admin_approval: true) }

  # Audit logging
  after_update :log_status_change, if: :saved_change_to_status?

  def hold_funds
    if escrow_wallet.hold_funds(amount)
      update(status: :held)
      notify_parties("Funds held in escrow")
      true
    else
      errors.add(:base, "Insufficient funds")
      false
    end
  end

  def release_funds(admin_approved: false)
    # Idempotency check - prevent duplicate releases
    if released?
      Rails.logger.warn("[ESCROW] Attempted duplicate release for transaction #{id}")
      return true
    end

    return false unless can_release_funds?(admin_approved)

    # Verify sufficient balance before transfer
    unless escrow_wallet.balance >= amount
      errors.add(:base, "Insufficient escrow balance: expected #{amount}, found #{escrow_wallet.balance}")
      log_error("Insufficient balance during release", { expected: amount, actual: escrow_wallet.balance })
      return false
    end

    transaction do
      receiver.escrow_wallet.receive_funds(amount)
      escrow_wallet.release_funds(amount)
      update!(status: :released, admin_approved_at: admin_approved ? Time.current : nil)
      notify_parties("Funds released to seller")
      log_transaction_event("Funds released", { amount: amount, admin_approved: admin_approved })
    end
    true
  rescue => e
    errors.add(:base, "Failed to release funds: #{e.message}")
    log_error("Release failed", { error: e.message, backtrace: e.backtrace.first(5) })
    false
  end

  def refund(refund_amount = nil, admin_approved: false)
    # Idempotency check - prevent duplicate refunds
    if refunded? || (partially_refunded? && refund_amount.nil?)
      Rails.logger.warn("[ESCROW] Attempted duplicate refund for transaction #{id}")
      return true
    end

    return false unless can_refund?(admin_approved)

    refund_amount ||= amount
    
    # Validate refund amount
    if refund_amount <= 0 || refund_amount > amount
      errors.add(:base, "Invalid refund amount: #{refund_amount} (must be between 0 and #{amount})")
      return false
    end

    # Verify sufficient balance
    unless escrow_wallet.balance >= refund_amount
      errors.add(:base, "Insufficient escrow balance for refund: expected #{refund_amount}, found #{escrow_wallet.balance}")
      log_error("Insufficient balance during refund", { expected: refund_amount, actual: escrow_wallet.balance })
      return false
    end

    transaction do
      sender.escrow_wallet.receive_funds(refund_amount)
      escrow_wallet.release_funds(refund_amount)
      
      if refund_amount == amount
        update!(status: :refunded)
      else
        update!(status: :partially_refunded, refunded_amount: refund_amount)
      end
      
      notify_parties("Refund processed: #{refund_amount}")
      log_transaction_event("Refund processed", { amount: refund_amount, admin_approved: admin_approved })
    end
    true
  rescue => e
    errors.add(:base, "Failed to process refund: #{e.message}")
    log_error("Refund failed", { error: e.message, backtrace: e.backtrace.first(5) })
    false
  end

  def initiate_dispute
    return false if disputed?
    
    transaction do
      update(status: :disputed)
      dispute = order.create_dispute!(
        buyer: sender,
        seller: receiver,
        amount: amount,
        escrow_transaction: self
      )
      notify_parties("Dispute initiated")
      DisputeAssignmentService.new(dispute).assign_mediator
    end
    true
  rescue => e
    errors.add(:base, "Failed to initiate dispute: #{e.message}")
    false
  end

  private

  def can_release_funds?(admin_approved)
    return false unless held?
    return true if admin_approved
    return false if needs_admin_approval && !admin_approved
    true
  end

  def can_refund?(admin_approved)
    return false unless held? || disputed?
    return true if admin_approved
    return false if needs_admin_approval && !admin_approved
    true
  end

  def notify_parties(message)
    [sender, receiver].each do |user|
      NotificationService.notify(
        user: user,
        title: "Escrow Update",
        message: message,
        resource: self
      )
    end
  end

  # Validation methods
  def sender_and_receiver_different
    if sender_id.present? && sender_id == receiver_id
      errors.add(:base, "Sender and receiver must be different users")
    end
  end

  def release_date_in_future
    if scheduled_release_at < Time.current
      errors.add(:scheduled_release_at, "must be in the future")
    end
  end

  # Audit logging methods
  def log_status_change
    Rails.logger.info("[ESCROW] Transaction #{id} status changed: #{status_before_last_save} → #{status}")
    log_transaction_event("Status changed", { 
      from: status_before_last_save, 
      to: status,
      order_id: order_id 
    })
  end

  def log_transaction_event(event, metadata = {})
    Rails.logger.info({
      event: "[ESCROW] #{event}",
      transaction_id: id,
      order_id: order_id,
      sender_id: sender_id,
      receiver_id: receiver_id,
      amount: amount,
      status: status,
      timestamp: Time.current,
      metadata: metadata
    }.to_json)
  end

  def log_error(error_type, details = {})
    Rails.logger.error({
      event: "[ESCROW ERROR] #{error_type}",
      transaction_id: id,
      order_id: order_id,
      details: details,
      timestamp: Time.current
    }.to_json)
  end
end