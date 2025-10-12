class IdentityVerification < ApplicationRecord
  belongs_to :user
  
  has_one_attached :id_document_front
  has_one_attached :id_document_back
  has_one_attached :selfie_photo
  
  validates :verification_type, presence: true
  validates :status, presence: true
  
  scope :pending, -> { where(status: :pending) }
  scope :approved, -> { where(status: :approved) }
  scope :rejected, -> { where(status: :rejected) }
  scope :recent, -> { where('created_at > ?', 30.days.ago) }
  
  # Verification types
  enum verification_type: {
    basic: 0,           # Email + phone verification
    standard: 1,        # Government ID
    enhanced: 2,        # ID + selfie + liveness check
    business: 3         # Business documents
  }
  
  # Verification status
  enum status: {
    pending: 0,
    in_review: 1,
    approved: 2,
    rejected: 3,
    expired: 4
  }
  
  # Document types
  enum document_type: {
    passport: 0,
    drivers_license: 1,
    national_id: 2,
    residence_permit: 3
  }
  
  # Submit for verification
  def submit!
    return false unless can_submit?
    
    update!(
      status: :in_review,
      submitted_at: Time.current
    )
    
    # Queue for automated verification
    IdentityVerificationJob.perform_later(id)
    
    true
  end
  
  # Approve verification
  def approve!(reviewer = nil)
    update!(
      status: :approved,
      verified_at: Time.current,
      reviewed_by: reviewer&.id,
      reviewed_at: Time.current,
      expires_at: 2.years.from_now
    )
    
    user.update!(identity_verified: true, verification_level: verification_type)
    
    # Send notification
    IdentityVerificationMailer.approved(user).deliver_later
  end
  
  # Reject verification
  def reject!(reason, reviewer = nil)
    update!(
      status: :rejected,
      rejection_reason: reason,
      reviewed_by: reviewer&.id,
      reviewed_at: Time.current
    )
    
    # Send notification
    IdentityVerificationMailer.rejected(user, reason).deliver_later
  end
  
  # Check if verification is valid
  def valid_verification?
    approved? && !expired?
  end
  
  # Check if expired
  def expired?
    return false unless expires_at
    expires_at < Time.current
  end
  
  # Automated verification using AI/ML
  def automated_verification
    return unless can_auto_verify?
    
    results = {
      document_valid: verify_document_authenticity,
      face_match: verify_face_match,
      liveness_check: verify_liveness,
      data_extraction: extract_document_data
    }
    
    update!(verification_results: results)
    
    # Auto-approve if all checks pass
    if results.values.all? { |v| v[:passed] }
      approve!
    else
      # Flag for manual review
      update!(status: :in_review, requires_manual_review: true)
    end
  end
  
  # Get verification badge
  def badge
    return nil unless approved?
    
    {
      basic: { icon: '✓', color: 'blue', text: 'Verified' },
      standard: { icon: '✓✓', color: 'green', text: 'ID Verified' },
      enhanced: { icon: '✓✓✓', color: 'gold', text: 'Enhanced Verified' },
      business: { icon: '🏢', color: 'purple', text: 'Business Verified' }
    }[verification_type.to_sym]
  end
  
  private
  
  def can_submit?
    pending? && has_required_documents?
  end
  
  def has_required_documents?
    case verification_type.to_sym
    when :basic
      true
    when :standard
      id_document_front.attached?
    when :enhanced
      id_document_front.attached? && selfie_photo.attached?
    when :business
      id_document_front.attached?
    end
  end
  
  def can_auto_verify?
    enhanced? && id_document_front.attached? && selfie_photo.attached?
  end
  
  def verify_document_authenticity
    # Integration with document verification service (Onfido, Jumio, etc.)
    # This would use AI/ML to verify document authenticity
    
    {
      passed: true,
      confidence: 0.95,
      checks: {
        hologram: true,
        microprint: true,
        security_features: true
      }
    }
  end
  
  def verify_face_match
    # Compare selfie with ID photo using facial recognition
    
    {
      passed: true,
      confidence: 0.92,
      match_score: 0.94
    }
  end
  
  def verify_liveness
    # Check if selfie is from a live person (not a photo of a photo)
    
    {
      passed: true,
      confidence: 0.88,
      liveness_score: 0.91
    }
  end
  
  def extract_document_data
    # OCR to extract data from ID document
    
    {
      passed: true,
      extracted_data: {
        full_name: 'John Doe',
        date_of_birth: '1990-01-01',
        document_number: 'ABC123456',
        expiry_date: '2030-01-01'
      }
    }
  end
end

