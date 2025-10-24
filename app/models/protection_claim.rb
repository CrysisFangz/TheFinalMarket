# frozen_string_literal: true

# ProtectionClaim model refactored for resilience and auditability.
# Claim processing logic extracted into dedicated service for compliance.
class ProtectionClaim < ApplicationRecord
  belongs_to :purchase_protection

  has_one :order, through: :purchase_protection
  has_one :user, through: :purchase_protection

  has_many_attached :evidence_files

  # Enhanced validations with custom messages
  validates :reason, presence: true, inclusion: { in: reasons.keys }
  validates :description, presence: true, length: { maximum: 1000 }
  validates :claim_amount_cents, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 10000000 }
  validates :evidence_files, presence: true, blob: { content_type: ['image/jpeg', 'image/png', 'application/pdf'] }

  # Enhanced scopes with performance optimization
  scope :pending, -> { where(status: :pending) }
  scope :approved, -> { where(status: :approved) }
  scope :rejected, -> { where(status: :rejected) }
  scope :recent, -> { order(filed_at: :desc) }
  scope :with_associations, -> { includes(:purchase_protection, :order, :user) }
  scope :by_reviewer, ->(reviewer_id) { where(reviewed_by: reviewer_id) }

  # Event-driven: Publish events on status changes
  after_create :publish_claim_filed_event
  after_update :publish_status_change_event, if: :saved_change_to_status?

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

  # Approve claim using service
  def approve!(reviewer, payout_amount = nil)
    ProtectionClaimService.approve_claim(self, reviewer, payout_amount)
  end

  # Reject claim using service
  def reject!(reviewer, reason)
    ProtectionClaimService.reject_claim(self, reviewer, reason)
  end

  private

  def publish_claim_filed_event
    Rails.logger.info("Protection claim filed: ID=#{id}, Reason=#{reason}, Amount=#{claim_amount_cents}")
    # In a full event system: EventPublisher.publish('protection_claim_filed', self.attributes)
  end

  def publish_status_change_event
    Rails.logger.info("Protection claim status changed: ID=#{id}, Status=#{status}")
    # In a full event system: EventPublisher.publish('protection_claim_status_changed', self.attributes)
  end
end

