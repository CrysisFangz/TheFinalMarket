class IdentityCheckService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'identity_check'
  CACHE_TTL = 30.minutes

  def self.valid_verification?(verification)
    cache_key = "#{CACHE_KEY_PREFIX}:valid:#{verification.id}:#{verification.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('identity_check') do
        with_retry do
          result = verification.approved? && !expired?(verification)

          EventPublisher.publish('identity_check.validity_checked', {
            verification_id: verification.id,
            user_id: verification.user_id,
            is_valid: result,
            status: verification.status,
            expires_at: verification.expires_at
          })

          result
        end
      end
    end
  end

  def self.expired?(verification)
    cache_key = "#{CACHE_KEY_PREFIX}:expired:#{verification.id}:#{verification.expires_at&.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('identity_check') do
        with_retry do
          result = false
          if verification.expires_at
            result = verification.expires_at < Time.current
          end

          EventPublisher.publish('identity_check.expiry_checked', {
            verification_id: verification.id,
            user_id: verification.user_id,
            is_expired: result,
            expires_at: verification.expires_at
          })

          result
        end
      end
    end
  end

  def self.get_badge(verification)
    cache_key = "#{CACHE_KEY_PREFIX}:badge:#{verification.id}:#{verification.verification_type}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('identity_check') do
        with_retry do
          return nil unless verification.approved?

          badge = {
            basic: { icon: '✓', color: 'blue', text: 'Verified' },
            standard: { icon: '✓✓', color: 'green', text: 'ID Verified' },
            enhanced: { icon: '✓✓✓', color: 'gold', text: 'Enhanced Verified' },
            business: { icon: '🏢', color: 'purple', text: 'Business Verified' }
          }[verification.verification_type.to_sym]

          EventPublisher.publish('identity_check.badge_generated', {
            verification_id: verification.id,
            user_id: verification.user_id,
            verification_type: verification.verification_type,
            badge: badge
          })

          badge
        end
      end
    end
  end

  def self.can_submit?(verification)
    cache_key = "#{CACHE_KEY_PREFIX}:can_submit:#{verification.id}:#{verification.status}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('identity_check') do
        with_retry do
          result = verification.pending? && has_required_documents?(verification)

          EventPublisher.publish('identity_check.submission_eligibility_checked', {
            verification_id: verification.id,
            user_id: verification.user_id,
            can_submit: result,
            status: verification.status,
            verification_type: verification.verification_type
          })

          result
        end
      end
    end
  end

  def self.has_required_documents?(verification)
    cache_key = "#{CACHE_KEY_PREFIX}:required_docs:#{verification.id}:#{verification.verification_type}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('identity_check') do
        with_retry do
          result = case verification.verification_type.to_sym
                   when :basic
                     true
                   when :standard
                     verification.id_document_front.attached?
                   when :enhanced
                     verification.id_document_front.attached? && verification.selfie_photo.attached?
                   when :business
                     verification.id_document_front.attached?
                   end

          EventPublisher.publish('identity_check.documents_checked', {
            verification_id: verification.id,
            user_id: verification.user_id,
            verification_type: verification.verification_type,
            has_required_documents: result
          })

          result
        end
      end
    end
  end

  def self.can_auto_verify?(verification)
    cache_key = "#{CACHE_KEY_PREFIX}:auto_verify:#{verification.id}:#{verification.verification_type}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('identity_check') do
        with_retry do
          result = verification.enhanced? && verification.id_document_front.attached? && verification.selfie_photo.attached?

          EventPublisher.publish('identity_check.auto_verification_eligibility_checked', {
            verification_id: verification.id,
            user_id: verification.user_id,
            can_auto_verify: result,
            verification_type: verification.verification_type
          })

          result
        end
      end
    end
  end

  def self.clear_identity_cache(verification_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:valid:#{verification_id}",
      "#{CACHE_KEY_PREFIX}:expired:#{verification_id}",
      "#{CACHE_KEY_PREFIX}:badge:#{verification_id}",
      "#{CACHE_KEY_PREFIX}:can_submit:#{verification_id}",
      "#{CACHE_KEY_PREFIX}:required_docs:#{verification_id}",
      "#{CACHE_KEY_PREFIX}:auto_verify:#{verification_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end