class EscrowTransaction < ApplicationRecord
  include CircuitBreaker
  include Retryable

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

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  def hold_funds
    with_retry do
      EscrowOperationsService.hold_funds(self)
    end
  end

  def release_funds(admin_approved: false)
    with_retry do
      EscrowOperationsService.release_funds(self, admin_approved: admin_approved)
    end
  end

  def refund(refund_amount = nil, admin_approved: false)
    with_retry do
      EscrowOperationsService.refund(self, refund_amount, admin_approved: admin_approved)
    end
  end

  def initiate_dispute
    with_retry do
      DisputeInitiationService.initiate_dispute(self)
    end
  end

  def can_release_funds?(admin_approved)
    Rails.cache.fetch("escrow_transaction:#{id}:can_release:#{admin_approved}", expires_in: 5.minutes) do
      return false unless held?
      return true if admin_approved
      return false if needs_admin_approval && !admin_approved
      true
    end
  end

  def can_refund?(admin_approved)
    Rails.cache.fetch("escrow_transaction:#{id}:can_refund:#{admin_approved}", expires_in: 5.minutes) do
      return false unless held? || disputed?
      return true if admin_approved
      return false if needs_admin_approval && !admin_approved
      true
    end
  end

  private

  def publish_created_event
    EventPublisher.publish('escrow_transaction.created', {
      transaction_id: id,
      escrow_wallet_id: escrow_wallet_id,
      order_id: order_id,
      sender_id: sender_id,
      receiver_id: receiver_id,
      amount: amount,
      transaction_type: transaction_type,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('escrow_transaction.updated', {
      transaction_id: id,
      escrow_wallet_id: escrow_wallet_id,
      order_id: order_id,
      sender_id: sender_id,
      receiver_id: receiver_id,
      amount: amount,
      status: status,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('escrow_transaction.destroyed', {
      transaction_id: id,
      escrow_wallet_id: escrow_wallet_id,
      order_id: order_id,
      sender_id: sender_id,
      receiver_id: receiver_id,
      amount: amount
    })
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