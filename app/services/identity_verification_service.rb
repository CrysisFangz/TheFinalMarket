class IdentityVerificationService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'identity_verification'
  CACHE_TTL = 10.minutes

  def self.submit_verification(verification)
    cache_key = "#{CACHE_KEY_PREFIX}:submit:#{verification.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('identity_verification') do
        with_retry do
          return false unless verification.can_submit?

          verification.update!(
            status: :in_review,
            submitted_at: Time.current
          )

          # Queue for automated verification
          IdentityVerificationJob.perform_later(verification.id)

          EventPublisher.publish('identity_verification.submitted', {
            verification_id: verification.id,
            user_id: verification.user_id,
            verification_type: verification.verification_type,
            submitted_at: verification.submitted_at
          })

          true
        end
      end
    end
  end

  def self.approve_verification(verification, reviewer = nil)
    cache_key = "#{CACHE_KEY_PREFIX}:approve:#{verification.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('identity_verification') do
        with_retry do
          verification.update!(
            status: :approved,
            verified_at: Time.current,
            reviewed_by: reviewer&.id,
            reviewed_at: Time.current,
            expires_at: 2.years.from_now
          )

          verification.user.update!(
            identity_verified: true,
            verification_level: verification.verification_type
          )

          # Send notification
          IdentityVerificationMailer.approved(verification.user).deliver_later

          EventPublisher.publish('identity_verification.approved', {
            verification_id: verification.id,
            user_id: verification.user_id,
            verification_type: verification.verification_type,
            verified_at: verification.verified_at,
            expires_at: verification.expires_at
          })

          true
        end
      end
    end
  end

  def self.reject_verification(verification, reason, reviewer = nil)
    cache_key = "#{CACHE_KEY_PREFIX}:reject:#{verification.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('identity_verification') do
        with_retry do
          verification.update!(
            status: :rejected,
            rejection_reason: reason,
            reviewed_by: reviewer&.id,
            reviewed_at: Time.current
          )

          # Send notification
          IdentityVerificationMailer.rejected(verification.user, reason).deliver_later

          EventPublisher.publish('identity_verification.rejected', {
            verification_id: verification.id,
            user_id: verification.user_id,
            verification_type: verification.verification_type,
            rejection_reason: reason,
            reviewed_at: verification.reviewed_at
          })

          true
        end
      end
    end
  end

  def self.clear_verification_cache(verification_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:submit:#{verification_id}",
      "#{CACHE_KEY_PREFIX}:approve:#{verification_id}",
      "#{CACHE_KEY_PREFIX}:reject:#{verification_id}",
      "#{CACHE_KEY_PREFIX}:valid:#{verification_id}",
      "#{CACHE_KEY_PREFIX}:expired:#{verification_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end