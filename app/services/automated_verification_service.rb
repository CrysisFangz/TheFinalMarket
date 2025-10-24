class AutomatedVerificationService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'automated_verification'
  CACHE_TTL = 20.minutes

  def self.perform_automated_verification(verification)
    cache_key = "#{CACHE_KEY_PREFIX}:verification:#{verification.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('automated_verification') do
        with_retry do
          return unless IdentityCheckService.can_auto_verify?(verification)

          results = {
            document_valid: DocumentValidationService.verify_document_authenticity(verification),
            face_match: DocumentValidationService.verify_face_match(verification),
            liveness_check: DocumentValidationService.verify_liveness(verification),
            data_extraction: DocumentValidationService.extract_document_data(verification)
          }

          verification.update!(verification_results: results)

          EventPublisher.publish('automated_verification.completed', {
            verification_id: verification.id,
            user_id: verification.user_id,
            verification_type: verification.verification_type,
            results: results,
            all_checks_passed: results.values.all? { |v| v[:passed] }
          })

          # Auto-approve if all checks pass
          if results.values.all? { |v| v[:passed] }
            IdentityVerificationService.approve_verification(verification)
          else
            # Flag for manual review
            verification.update!(status: :in_review, requires_manual_review: true)

            EventPublisher.publish('automated_verification.requires_manual_review', {
              verification_id: verification.id,
              user_id: verification.user_id,
              verification_type: verification.verification_type,
              failed_checks: results.select { |k, v| !v[:passed] }.keys
            })
          end

          results
        end
      end
    end
  end

  def self.clear_verification_cache(verification_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:verification:#{verification_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end