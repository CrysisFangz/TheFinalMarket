class WalletTransaction < ApplicationRecord
  belongs_to :mobile_wallet
  
  validates :mobile_wallet, presence: true
  validates :transaction_type, presence: true
  validates :amount_cents, numericality: { greater_than: 0 }
  
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
  
  # Get amount in dollars
  def amount
    amount_cents / 100.0
  end
  
  # Get balance after in dollars
  def balance_after
    balance_after_cents / 100.0
  end
  
  # Get transaction description
  def description
    case transaction_type.to_sym
    when :credit
      "Added funds from #{source}"
    when :debit
      "Payment for #{purpose}"
    when :refund
      "Refund for #{purpose}"
    when :adjustment
      "Balance adjustment"
    end
  end
end

