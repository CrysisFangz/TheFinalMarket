class IdentityVerificationJob < ApplicationJob
  queue_as :default
  
  def perform(verification_id)
    verification = IdentityVerification.find(verification_id)
    
    Rails.logger.info "Processing identity verification #{verification_id}"
    
    begin
      # Perform automated verification
      verification.automated_verification
      
      Rails.logger.info "Identity verification #{verification_id} processed successfully"
    rescue => e
      Rails.logger.error "Failed to process identity verification #{verification_id}: #{e.message}"
      
      # Flag for manual review
      verification.update!(
        status: :in_review,
        requires_manual_review: true
      )
      
      raise e
    end
  end
end

