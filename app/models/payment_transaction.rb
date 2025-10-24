class PaymentTransaction < ApplicationRecord
  belongs_to :source_account, class_name: 'PaymentAccount'
  belongs_to :target_account, class_name: 'PaymentAccount', optional: true
  belongs_to :order, optional: true

  monetize :amount_cents

  enum transaction_type: {
    purchase: 'purchase',
    refund: 'refund',
    payout: 'payout',
    fee: 'fee',
    bond: 'bond',
    bond_refund: 'bond_refund'
  }

  enum status: {
    pending: 'pending',
    processing: 'processing',
    held: 'held',
    completed: 'completed',
    failed: 'failed',
    refunded: 'refunded',
    cancelled: 'cancelled'
  }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :transaction_type, presence: true
  validates :status, presence: true
  validates :square_payment_id, uniqueness: true, allow_nil: true
  validates :square_refund_id, uniqueness: true, allow_nil: true
  validates :square_transfer_id, uniqueness: true, allow_nil: true

  before_create :set_description
  after_create :process_transaction

  private

  def set_description
    self.description = description_service.generate_description
  end

  def process_transaction
    processing_service.process_transaction
  end

  def description_service
    @description_service ||= PaymentTransactionDescriptionService.new(self)
  end

  def processing_service
    @processing_service ||= PaymentTransactionProcessingService.new(self)
  end
end
