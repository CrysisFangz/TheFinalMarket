class SecurityScorer
  include CircuitBreaker

  BASE_SCORE = 100
  PENALTIES = {
    login_failure: 2,
    suspicious_activity: 10,
    failed_authorization: 5,
    security_breach: 50
  }.freeze
  BONUSES = {
    two_factor_active: 10,
    identity_verified: 5,
    data_processing_consent: 5
  }.freeze

  def self.score_for(user)
    with_circuit_breaker(name: 'security_scoring') do
      cache_key = "security_score_user_#{user.id}_#{user.updated_at.to_i}"

      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        events = SecurityAudit.where(user: user).where('created_at > ?', 30.days.ago)

        score = BASE_SCORE

        # Aggregate penalties in one query
        penalties = events.group(:event_type).count
        PENALTIES.each do |event, penalty|
          score -= penalties[event.to_s] * penalty if penalties[event.to_s]
        end

        # Add bonuses
        score += BONUSES[:two_factor_active] if user.two_factor_authentications.active.any?
        score += BONUSES[:identity_verified] if user.identity_verified?
        score += BONUSES[:data_processing_consent] if user.privacy_setting&.data_processing_consent

        [score, 0].max
      end
    end
  rescue => e
    Rails.logger.error("Error calculating security score: #{e.message}")
    0
  end
end