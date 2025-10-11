class ProtectionClaim < ApplicationRecord
  belongs_to :purchase_protection
  
  has_one :order, through: :purchase_protection
  has_one :user, through: :purchase_protection
  
  has_many_attached :evidence_files
  
  validates :reason, presence: true
  validates :description, presence: true
  validates :claim_amount_cents, presence: true
  
  scope :pending, -> { where(status: :pending) }
  scope :approved, -> { where(status: :approved) }
  scope :rejected, -> { where(status: :rejected) }
  scope :recent, -> { order(filed_at: :desc) }
  
  # Claim reasons
  enum reason: {
    item_not_received: 0,
    item_not_as_described: 1,
    item_damaged: 2,
    item_defective: 3,
    unauthorized_transaction: 4,
    price_drop: 5,
    other: 9
  }
  
  # Claim status
  enum status: {
    pending: 0,
    under_review: 1,
    approved: 2,
    rejected: 3,
    paid: 4
  }
  
  # Approve claim
  def approve!(reviewer, payout_amount = nil)
    payout = payout_amount || claim_amount_cents
    
    update!(
      status: :approved,
      approved_amount_cents: payout,
      reviewed_by: reviewer.id,
      reviewed_at: Time.current,
      resolution_notes: 'Claim approved'
    )
    
    # Process payout
    process_payout(payout)
    
    # Notify user
    ProtectionClaimMailer.approved(self).deliver_later
  end
  
  # Reject claim
  def reject!(reviewer, reason)
    update!(
      status: :rejected,
      reviewed_by: reviewer.id,
      reviewed_at: Time.current,
      resolution_notes: reason
    )
    
    # Notify user
    ProtectionClaimMailer.rejected(self, reason).deliver_later
  end
  
  # Process payout
  def process_payout(amount)
    # Create refund
    refund = Refund.create!(
      order: order,
      amount_cents: amount,
      reason: 'Protection claim payout',
      status: :pending
    )
    
    # Process refund
    refund.process!
    
    update!(status: :paid, paid_at: Time.current)
  end
end

