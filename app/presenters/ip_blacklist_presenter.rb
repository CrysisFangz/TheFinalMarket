class IpBlacklistPresenter
  include CircuitBreaker
  include Retryable

  def initialize(blacklist_entry)
    @blacklist_entry = blacklist_entry
  end

  def as_json(options = {})
    cache_key = "ip_blacklist_presenter:#{@blacklist_entry.id}:#{@blacklist_entry.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      with_circuit_breaker('ip_blacklist_presenter') do
        with_retry do
          {
            id: @blacklist_entry.id,
            ip_address: @blacklist_entry.ip_address,
            reason: @blacklist_entry.reason,
            severity: @blacklist_entry.severity,
            permanent: @blacklist_entry.permanent,
            expires_at: @blacklist_entry.expires_at,
            added_by: @blacklist_entry.added_by,
            created_at: @blacklist_entry.created_at,
            updated_at: @blacklist_entry.updated_at,
            is_active: @blacklist_entry.active?,
            is_expired: @blacklist_entry.expired?,
            days_until_expiry: days_until_expiry,
            added_by_user: added_by_user_data,
            validation_status: validation_status,
            threat_analysis: threat_analysis,
            risk_assessment: risk_assessment
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
        block_count: @blacklist_entry.block_count,
        last_activity: @blacklist_entry.last_activity,
        related_entries: related_entries,
        investigation_notes: @blacklist_entry.investigation_notes,
        requires_review: requires_review?
      }
    )
  end

  private

  def days_until_expiry
    return nil if @blacklist_entry.permanent? || @blacklist_entry.expires_at.nil?

    [(Time.current - @blacklist_entry.expires_at).to_i / 86400, 0].max
  end

  def added_by_user_data
    return nil unless @blacklist_entry.added_by

    Rails.cache.fetch("blacklist_added_by:#{@blacklist_entry.added_by}", expires_in: 30.minutes) do
      with_circuit_breaker('added_by_data') do
        with_retry do
          user = User.find_by(id: @blacklist_entry.added_by)
          return nil unless user

          {
            id: user.id,
            username: user.username,
            role: user.role,
            reputation_score: user.reputation_score
          }
        end
      end
    end
  end

  def validation_status
    Rails.cache.fetch("blacklist_validation:#{@blacklist_entry.id}", expires_in: 15.minutes) do
      with_circuit_breaker('validation_status') do
        with_retry do
          validation = IpValidationService.validate_ip_address(@blacklist_entry.ip_address)

          {
            is_valid_format: validation[:valid] || validation[:reason] == 'IP address is blacklisted',
            blacklist_status: validation[:reason] == 'IP address is blacklisted' ? 'confirmed' : 'not_blacklisted',
            reputation_score: IpValidationService.check_ip_reputation(@blacklist_entry.ip_address)[:score],
            threat_level: IpValidationService.check_threat_intelligence(@blacklist_entry.ip_address)[:threat_level]
          }
        end
      end
    end
  end

  def threat_analysis
    Rails.cache.fetch("blacklist_threat:#{@blacklist_entry.id}", expires_in: 20.minutes) do
      with_circuit_breaker('threat_analysis') do
        with_retry do
          threat_intel = IpValidationService.check_threat_intelligence(@blacklist_entry.ip_address)
          geolocation = IpValidationService.get_ip_geolocation(@blacklist_entry.ip_address)

          {
            threat_score: threat_intel[:threat_score],
            threat_level: threat_intel[:threat_level],
            threat_indicators: threat_intel[:indicators],
            geolocation: geolocation,
            risk_factors: identify_risk_factors,
            attack_patterns: detect_attack_patterns
          }
        end
      end
    end
  end

  def risk_assessment
    Rails.cache.fetch("blacklist_risk:#{@blacklist_entry.id}", expires_in: 15.minutes) do
      with_circuit_breaker('risk_assessment') do
        with_retry do
          risk_score = calculate_risk_score

          {
            risk_score: risk_score,
            risk_level: risk_level_from_score(risk_score),
            risk_factors: identify_risk_factors,
            mitigation_priority: mitigation_priority(risk_score),
            recommended_actions: generate_recommended_actions
          }
        end
      end
    end
  end

  def related_entries
    Rails.cache.fetch("blacklist_related:#{@blacklist_entry.id}", expires_in: 10.minutes) do
      with_circuit_breaker('related_entries') do
        with_retry do
          # Find entries with similar IP patterns or reasons
          similar_entries = IpBlacklist.where('ip_address LIKE ? OR reason = ?',
                                            "#{@blacklist_entry.ip_address.split('.').first(2).join('.')}.%",
                                            @blacklist_entry.reason)
                                     .where.not(id: @blacklist_entry.id)
                                     .limit(10)
                                     .pluck(:id, :ip_address, :reason)

          similar_entries.map do |id, ip, reason|
            {
              id: id,
              ip_address: ip,
              reason: reason,
              similarity_score: calculate_similarity_score(@blacklist_entry, ip, reason)
            }
          end
        end
      end
    end
  end

  def requires_review?
    @blacklist_entry.permanent? || @blacklist_entry.severity >= 3 || days_until_expiry&.<= 7
  end

  def identify_risk_factors
    factors = []

    factors << 'permanent_blacklist' if @blacklist_entry.permanent?
    factors << 'high_severity' if @blacklist_entry.severity >= 3
    factors << 'frequent_offender' if (@blacklist_entry.block_count || 0) >= 5
    factors << 'expiring_soon' if days_until_expiry&.<= 7
    factors << 'no_investigation' if @blacklist_entry.investigation_notes.blank?

    factors
  end

  def detect_attack_patterns
    patterns = []

    # Analyze IP for common attack patterns
    ip_parts = @blacklist_entry.ip_address.split('.')

    if ip_parts.first == '192' && ip_parts.second == '168'
      patterns << 'private_network_access'
    end

    if @blacklist_entry.reason.include?('brute_force') || @blacklist_entry.reason.include?('login')
      patterns << 'authentication_attack'
    end

    if @blacklist_entry.reason.include?('sql') || @blacklist_entry.reason.include?('injection')
      patterns << 'injection_attack'
    end

    if @blacklist_entry.reason.include?('spam') || @blacklist_entry.reason.include?('bot')
      patterns << 'automated_attack'
    end

    patterns
  end

  def calculate_risk_score
    score = 0

    # Base score from severity
    score += @blacklist_entry.severity * 20

    # Permanent entries are higher risk
    score += 30 if @blacklist_entry.permanent?

    # Frequent offenders are higher risk
    score += [(@blacklist_entry.block_count || 0) * 10, 50].min

    # Expiring soon entries need attention
    if days_until_expiry&.<= 7
      score += 20
    end

    # High threat intelligence score increases risk
    threat_intel = IpValidationService.check_threat_intelligence(@blacklist_entry.ip_address)
    score += threat_intel[:threat_score] / 2

    [score, 100].min
  end

  def risk_level_from_score(score)
    case score
    when 0..20
      'low'
    when 21..50
      'medium'
    when 51..80
      'high'
    else
      'critical'
    end
  end

  def mitigation_priority(score)
    case score
    when 0..20
      'low'
    when 21..50
      'medium'
    when 51..80
      'high'
    else
      'urgent'
    end
  end

  def generate_recommended_actions
    actions = []

    if @blacklist_entry.permanent?
      actions << 'Review permanent status - consider temporary if threat level decreased'
    end

    if @blacklist_entry.severity >= 3
      actions << 'Investigate threat source and attack patterns'
    end

    if days_until_expiry&.<= 7
      actions << 'Review expiry - extend if threat persists'
    end

    if @blacklist_entry.investigation_notes.blank?
      actions << 'Add investigation notes and context'
    end

    actions << 'Monitor for related IP addresses' if related_entries.any?

    actions
  end

  def calculate_similarity_score(entry, ip, reason)
    score = 0

    # IP similarity (same subnet)
    entry_parts = entry.ip_address.split('.')
    ip_parts = ip.split('.')

    if entry_parts.first(3) == ip_parts.first(3)
      score += 50
    elsif entry_parts.first(2) == ip_parts.first(2)
      score += 25
    end

    # Reason similarity
    if entry.reason == reason
      score += 30
    elsif entry.reason.include?(reason) || reason.include?(entry.reason)
      score += 15
    end

    score
  end
end