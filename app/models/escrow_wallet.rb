class EscrowWallet < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :user
  has_many :escrow_transactions
  has_many :held_orders, class_name: 'Order', foreign_key: 'escrow_wallet_id'

  validates :balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :user_id, presence: true, uniqueness: true

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  def hold_funds(amount)
    with_retry do
      WalletOperationsService.hold_funds(self, amount)
    end
  end

  def release_funds(amount)
    with_retry do
      WalletOperationsService.release_funds(self, amount)
    end
  end

  def receive_funds(amount)
    with_retry do
      WalletOperationsService.receive_funds(self, amount)
    end
  end

  def withdraw_funds(amount)
    with_retry do
      WalletOperationsService.withdraw_funds(self, amount)
    end
  end

  def total_balance
    Rails.cache.fetch("escrow_wallet:#{id}:total_balance", expires_in: 1.minute) do
      balance + held_balance
    end
  end

  def available_balance
    Rails.cache.fetch("escrow_wallet:#{id}:available_balance", expires_in: 1.minute) do
      balance
    end
  end

  private

  def publish_created_event
    EventPublisher.publish('escrow_wallet.created', {
      wallet_id: id,
      user_id: user_id,
      balance: balance,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('escrow_wallet.updated', {
      wallet_id: id,
      user_id: user_id,
      balance: balance,
      held_balance: held_balance,
      total_balance: total_balance,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('escrow_wallet.destroyed', {
      wallet_id: id,
      user_id: user_id,
      balance: balance,
      held_balance: held_balance
    })
  end
end