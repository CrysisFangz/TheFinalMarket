class WalletTransaction < ApplicationRecord
  belongs_to :mobile_wallet

  validates :mobile_wallet, presence: true
  validates :transaction_type, presence: true, inclusion: { in: transaction_types.keys }
  validates :amount_cents, numericality: { greater_than: 0, only_integer: true }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validate :validate_balance_sufficiency, if: :debit?

  # Class method to create transactions using the service for better decoupling
  def self.create_transaction(wallet, type, amount_cents, source: nil, purpose: nil)
    WalletTransactionService.create_transaction(wallet, type, amount_cents, source: source, purpose: purpose)
  end

  private

  def validate_balance_sufficiency
    return unless mobile_wallet

    current_balance = WalletTransactionService.calculate_balance(mobile_wallet)
    if current_balance.cents < amount_cents
      errors.add(:amount_cents, "insufficient balance")
    end
  end
  
  enum transaction_type: {
    credit: 0,
    debit: 1,
    refund: 2,
    adjustment: 3
  }
  
  enum status: {
    pending: 0,
    completed: 1,
    failed: 2,
    reversed: 3
  }
  
  # Scopes
  scope :credits, -> { where(transaction_type: :credit) }
  scope :debits, -> { where(transaction_type: :debit) }
  scope :completed, -> { where(status: :completed) }
  scope :recent, -> { where('processed_at > ?', 30.days.ago) }
  
  # Delegate to Value Objects for precision
  def amount
    Amount.new(amount_cents)
  end

  def balance_after
    Balance.new(balance_after_cents)
  end

  # Use Presenter for description
  def description
    WalletTransactionPresenter.new(self).description
  end

  # Convenience methods
  def formatted_amount
    amount.to_s
  end

  def formatted_balance_after
    balance_after.to_s
  end
end

