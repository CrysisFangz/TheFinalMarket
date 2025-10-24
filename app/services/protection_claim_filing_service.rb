# frozen_string_literal: true

# Service for filing protection claims with comprehensive validation and workflow.
# Ensures proper claim processing and maintains audit trails.
class ProtectionClaimFilingService
  # Files a claim for purchase protection.
  # @param purchase_protection [PurchaseProtection] The protection to claim against.
  # @param reason [Symbol] The claim reason.
  # @param description [String] Claim description.
  # @param evidence [Hash] Evidence data.
  # @return [ProtectionClaim] The created claim.
  def self.file_claim(purchase_protection, reason, description, evidence = {})
    return false unless purchase_protection.can_file_claim?

    purchase_protection.transaction do
      claim = purchase_protection.protection_claims.create!(
        reason: reason,
        description: description,
        evidence: evidence,
        claim_amount_cents: purchase_protection.coverage_amount_cents,
        filed_at: Time.current,
        status: :pending
      )

      purchase_protection.update!(status: :claimed)

      # Send notification
      ProtectionClaimMailer.new_claim(claim).deliver_later

      # Publish event
      EventPublisher.publish('protection_claim_filed', {
        claim_id: claim.id,
        protection_id: purchase_protection.id,
        reason: reason,
        amount: purchase_protection.coverage_amount_cents
      })

      claim
    end
  rescue StandardError => e
    Rails.logger.error("Failed to file claim for protection #{purchase_protection.id}: #{e.message}")
    false
  end
end