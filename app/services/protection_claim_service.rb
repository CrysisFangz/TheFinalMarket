# frozen_string_literal: true

# Service for processing protection claims with comprehensive workflow management.
# Ensures compliance, auditability, and efficient claim resolution.
class ProtectionClaimService
  # Approves a protection claim and processes payout.
  # @param claim [ProtectionClaim] The claim to approve.
  # @param reviewer [User] The reviewer approving the claim.
  # @param payout_amount [Integer] Optional custom payout amount in cents.
  # @return [Boolean] True if approved successfully.
  def self.approve_claim(claim, reviewer, payout_amount = nil)
    payout = payout_amount || claim.claim_amount_cents

    claim.transaction do
      claim.update!(
        status: :approved,
        approved_amount_cents: payout,
        reviewed_by: reviewer.id,
        reviewed_at: Time.current,
        resolution_notes: 'Claim approved'
      )

      # Process payout
      process_payout(claim, payout)

      # Send notification
      ProtectionClaimMailer.approved(claim).deliver_later
    end

    # Publish event
    EventPublisher.publish('protection_claim_approved', {
      claim_id: claim.id,
      payout_amount: payout,
      reviewer_id: reviewer.id
    })

    true
  rescue StandardError => e
    Rails.logger.error("Failed to approve claim #{claim.id}: #{e.message}")
    false
  end

  # Rejects a protection claim.
  # @param claim [ProtectionClaim] The claim to reject.
  # @param reviewer [User] The reviewer rejecting the claim.
  # @param reason [String] The rejection reason.
  # @return [Boolean] True if rejected successfully.
  def self.reject_claim(claim, reviewer, reason)
    claim.transaction do
      claim.update!(
        status: :rejected,
        reviewed_by: reviewer.id,
        reviewed_at: Time.current,
        resolution_notes: reason
      )

      # Send notification
      ProtectionClaimMailer.rejected(claim, reason).deliver_later
    end

    # Publish event
    EventPublisher.publish('protection_claim_rejected', {
      claim_id: claim.id,
      reason: reason,
      reviewer_id: reviewer.id
    })

    true
  rescue StandardError => e
    Rails.logger.error("Failed to reject claim #{claim.id}: #{e.message}")
    false
  end

  private

  def self.process_payout(claim, amount)
    # Create refund
    refund = Refund.create!(
      order: claim.order,
      amount_cents: amount,
      reason: 'Protection claim payout',
      status: :pending
    )

    # Process refund
    refund.process!

    claim.update!(status: :paid, paid_at: Time.current)
  end
end