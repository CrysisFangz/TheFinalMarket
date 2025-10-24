class IdentityVerificationPresenter
  include CircuitBreaker
  include Retryable

  def initialize(verification)
    @verification = verification
  end

  def as_json(options = {})
    cache_key = "identity_verification_presenter:#{@verification.id}:#{@verification.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      with_circuit_breaker('verification_presenter') do
        with_retry do
          {
            id: @verification.id,
            user_id: @verification.user_id,
            verification_type: @verification.verification_type,
            status: @verification.status,
            document_type: @verification.document_type,
            created_at: @verification.created_at,
            updated_at: @verification.updated_at,
            submitted_at: @verification.submitted_at,
            verified_at: @verification.verified_at,
            expires_at: @verification.expires_at,
            rejection_reason: @verification.rejection_reason,
            verification_results: @verification.verification_results,
            badge: IdentityCheckService.get_badge(@verification),
            is_valid: IdentityCheckService.valid_verification?(@verification),
            is_expired: IdentityCheckService.expired?(@verification),
            can_submit: IdentityCheckService.can_submit?(@verification),
            requires_manual_review: @verification.requires_manual_review,
            user: user_data,
            documents: document_data
          }
        end
      end
    end
  end

  def to_api_response
    as_json.merge(
      metadata: {
        cache_timestamp: Time.current,
        version: '1.0'
      }
    )
  end

  def to_admin_response
    as_json.merge(
      admin_data: {
        reviewed_by: reviewer_data,
        reviewed_at: @verification.reviewed_at,
        internal_notes: @verification.internal_notes,
        risk_score: @verification.risk_score
      }
    )
  end

  private

  def user_data
    Rails.cache.fetch("user_data:#{@verification.user_id}", expires_in: 30.minutes) do
      with_circuit_breaker('user_data') do
        with_retry do
          {
            id: @verification.user.id,
            username: @verification.user.username,
            email: @verification.user.email,
            identity_verified: @verification.user.identity_verified,
            verification_level: @verification.user.verification_level
          }
        end
      end
    end
  end

  def document_data
    Rails.cache.fetch("verification_documents:#{@verification.id}", expires_in: 15.minutes) do
      with_circuit_breaker('document_data') do
        with_retry do
          {
            id_document_front: @verification.id_document_front.attached? ? {
              filename: @verification.id_document_front.filename,
              size: @verification.id_document_front.byte_size,
              content_type: @verification.id_document_front.content_type
            } : nil,
            id_document_back: @verification.id_document_back.attached? ? {
              filename: @verification.id_document_back.filename,
              size: @verification.id_document_back.byte_size,
              content_type: @verification.id_document_back.content_type
            } : nil,
            selfie_photo: @verification.selfie_photo.attached? ? {
              filename: @verification.selfie_photo.filename,
              size: @verification.selfie_photo.byte_size,
              content_type: @verification.selfie_photo.content_type
            } : nil
          }
        end
      end
    end
  end

  def reviewer_data
    return nil unless @verification.reviewed_by

    Rails.cache.fetch("reviewer_data:#{@verification.reviewed_by}", expires_in: 30.minutes) do
      with_circuit_breaker('reviewer_data') do
        with_retry do
          reviewer = User.find_by(id: @verification.reviewed_by)
          return nil unless reviewer

          {
            id: reviewer.id,
            username: reviewer.username,
            role: reviewer.role
          }
        end
      end
    end
  end
end