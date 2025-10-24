class IdentityVerification < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :user

  has_one_attached :id_document_front
  has_one_attached :id_document_back
  has_one_attached :selfie_photo

  validates :verification_type, presence: true
  validates :status, presence: true

  # Enhanced scopes with caching
  scope :pending, -> { where(status: :pending) }
  scope :approved, -> { where(status: :approved) }
  scope :rejected, -> { where(status: :rejected) }
  scope :recent, -> { where('created_at > ?', 30.days.ago) }

  # Caching
  after_create :clear_identity_cache
  after_update :clear_identity_cache
  after_destroy :clear_identity_cache

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event
  
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
    IdentityVerificationService.submit_verification(self)
  end

  # Approve verification
  def approve!(reviewer = nil)
    IdentityVerificationService.approve_verification(self, reviewer)
  end

  # Reject verification
  def reject!(reason, reviewer = nil)
    IdentityVerificationService.reject_verification(self, reason, reviewer)
  end

  # Check if verification is valid
  def valid_verification?
    IdentityCheckService.valid_verification?(self)
  end

  # Check if expired
  def expired?
    IdentityCheckService.expired?(self)
  end
  
  # Automated verification using AI/ML
  def automated_verification
    AutomatedVerificationService.perform_automated_verification(self)
  end

  # Get verification badge
  def badge
    IdentityCheckService.get_badge(self)
  end
  
  def self.cached_find(id)
    Rails.cache.fetch("identity_verification:#{id}", expires_in: 30.minutes) do
      find_by(id: id)
    end
  end

  def self.cached_pending_count
    Rails.cache.fetch("identity_verification_pending_count", expires_in: 5.minutes) do
      pending.count
    end
  end

  def self.cached_approved_count
    Rails.cache.fetch("identity_verification_approved_count", expires_in: 5.minutes) do
      approved.count
    end
  end

  def presenter
    @presenter ||= IdentityVerificationPresenter.new(self)
  end

  private

  def clear_identity_cache
    IdentityVerificationService.clear_verification_cache(id)
    IdentityCheckService.clear_identity_cache(id)
    DocumentValidationService.clear_document_cache(id)
    AutomatedVerificationService.clear_verification_cache(id)

    # Clear related caches
    Rails.cache.delete("identity_verification:#{id}")
    Rails.cache.delete("identity_verification_pending_count")
    Rails.cache.delete("identity_verification_approved_count")
  end

  def publish_created_event
    EventPublisher.publish('identity_verification.created', {
      verification_id: id,
      user_id: user_id,
      verification_type: verification_type,
      status: status,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('identity_verification.updated', {
      verification_id: id,
      user_id: user_id,
      verification_type: verification_type,
      status: status,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('identity_verification.destroyed', {
      verification_id: id,
      user_id: user_id,
      verification_type: verification_type,
      status: status
    })
  end
end

