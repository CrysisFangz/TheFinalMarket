class EscrowHold < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :payment_account
  belongs_to :order, optional: true

  monetize :amount_cents

  enum status: {
    active: 'active',
    released: 'released',
    expired: 'expired'
  }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :reason, presence: true
  validates :status, presence: true

  scope :expiring, -> { active.where('expires_at <= ?', 24.hours.from_now) }

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  def release!
    with_retry do
      EscrowManagementService.release!(self)
    end
  end

  def expire!
    with_retry do
      EscrowManagementService.expire!(self)
    end
  end

  def expiring_soon?
    expires_at <= 24.hours.from_now
  end

  def days_until_expiry
    (expires_at.to_date - Date.current).to_i
  end

  private

  def publish_created_event
    EventPublisher.publish('escrow_hold.created', {
      escrow_hold_id: id,
      payment_account_id: payment_account_id,
      order_id: order_id,
      amount: amount,
      reason: reason,
      expires_at: expires_at,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('escrow_hold.updated', {
      escrow_hold_id: id,
      payment_account_id: payment_account_id,
      order_id: order_id,
      amount: amount,
      status: status,
      released_at: released_at,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('escrow_hold.destroyed', {
      escrow_hold_id: id,
      payment_account_id: payment_account_id,
      order_id: order_id,
      amount: amount
    })
  end
end