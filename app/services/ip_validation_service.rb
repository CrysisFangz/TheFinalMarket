class IpValidationService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'ip_validation'
  CACHE_TTL = 15.minutes

  def self.validate_ip_address(ip)
    cache_key = "#{CACHE_KEY_PREFIX}:validate:#{ip}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('ip_validation') do
        with_retry do
          # Basic IP address validation
          unless valid_ip_format?(ip)
            EventPublisher.publish('ip_validation.invalid_format', {
              ip_address: ip,
              validation_result: 'invalid_format',
              validated_at: Time.current
            })
            return { valid: false, reason: 'Invalid IP address format' }
          end

          # Check if blacklisted
          is_blacklisted = IpBlacklistManagementService.check_blacklisted(ip)

          if is_blacklisted
            blacklist_entry = IpBlacklist.active.find_by(ip_address: ip)

            EventPublisher.publish('ip_validation.blacklisted', {
              ip_address: ip,
              blacklist_entry_id: blacklist_entry&.id,
              reason: blacklist_entry&.reason,
              severity: blacklist_entry&.severity,
              validation_result: 'blacklisted',
              validated_at: Time.current
            })

            return {
              valid: false,
              reason: 'IP address is blacklisted',
              blacklist_entry: {
                id: blacklist_entry.id,
                reason: blacklist_entry.reason,
                severity: blacklist_entry.severity,
                expires_at: blacklist_entry.expires_at
              }
            }
          end

          # Additional validation checks
          validation_result = perform_additional_checks(ip)

          EventPublisher.publish('ip_validation.completed', {
            ip_address: ip,
            validation_result: validation_result[:valid] ? 'valid' : 'additional_checks_failed',
            reason: validation_result[:reason],
            validated_at: Time.current
          })

          validation_result
        end
      end
    end
  end

  def self.check_ip_reputation(ip)
    cache_key = "#{CACHE_KEY_PREFIX}:reputation:#{ip}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('ip_validation') do
        with_retry do
          # This would integrate with external reputation services
          # For now, we'll use internal data

          blacklist_entry = IpBlacklist.find_by(ip_address: ip)

          reputation = {
            score: calculate_reputation_score(blacklist_entry),
            risk_level: calculate_risk_level(blacklist_entry),
            last_activity: blacklist_entry&.created_at,
            block_count: blacklist_entry&.block_count || 0
          }

          EventPublisher.publish('ip_validation.reputation_checked', {
            ip_address: ip,
            reputation_score: reputation[:score],
            risk_level: reputation[:risk_level],
            checked_at: Time.current
          })

          reputation
        end
      end
    end
  end

  def self.validate_ip_range(ip_range)
    cache_key = "#{CACHE_KEY_PREFIX}:range:#{ip_range}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('ip_validation') do
        with_retry do
          unless valid_cidr_format?(ip_range)
            return { valid: false, reason: 'Invalid CIDR format' }
          end

          # Check if any IP in range is blacklisted
          network = IPAddr.new(ip_range)
          blacklisted_count = IpBlacklist.active.where('INET_ATON(ip_address) BETWEEN INET_ATON(?) AND INET_ATON(?)',
                                                      network.to_s.split('/').first,
                                                      network.broadcast.to_s).count

          if blacklisted_count > 0
            return {
              valid: false,
              reason: "#{blacklisted_count} blacklisted IPs found in range",
              blacklisted_count: blacklisted_count
            }
          end

          { valid: true, total_ips: network.to_range.count }
        end
      end
    end
  end

  def self.get_ip_geolocation(ip)
    cache_key = "#{CACHE_KEY_PREFIX}:geolocation:#{ip}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('ip_validation') do
        with_retry do
          # This would integrate with geolocation services like MaxMind
          # For now, return basic info

          geolocation = {
            country: 'Unknown',
            region: 'Unknown',
            city: 'Unknown',
            latitude: nil,
            longitude: nil,
            timezone: 'Unknown',
            isp: 'Unknown'
          }

          EventPublisher.publish('ip_validation.geolocation_retrieved', {
            ip_address: ip,
            country: geolocation[:country],
            region: geolocation[:region],
            retrieved_at: Time.current
          })

          geolocation
        end
      end
    end
  end

  def self.check_threat_intelligence(ip)
    cache_key = "#{CACHE_KEY_PREFIX}:threat_intel:#{ip}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('ip_validation') do
        with_retry do
          # This would integrate with threat intelligence services
          # For now, use internal threat scoring

          blacklist_entry = IpBlacklist.find_by(ip_address: ip)

          threat_score = 0
          threat_score += 50 if blacklist_entry&.permanent?
          threat_score += blacklist_entry&.severity || 0
          threat_score += [blacklist_entry&.block_count || 0, 50].min

          threat_level = case threat_score
                        when 0..20
                          'low'
                        when 21..50
                          'medium'
                        when 51..80
                          'high'
                        else
                          'critical'
                        end

          threat_intel = {
            threat_score: threat_score,
            threat_level: threat_level,
            indicators: generate_threat_indicators(blacklist_entry),
            last_updated: Time.current
          }

          EventPublisher.publish('ip_validation.threat_intel_checked', {
            ip_address: ip,
            threat_score: threat_score,
            threat_level: threat_level,
            checked_at: Time.current
          })

          threat_intel
        end
      end
    end
  end

  private

  def self.valid_ip_format?(ip)
    # Validate IPv4 or IPv6 format
    IPAddr.new(ip)
    true
  rescue IPAddr::InvalidAddressError
    false
  end

  def self.valid_cidr_format?(cidr)
    IPAddr.new(cidr)
    true
  rescue IPAddr::InvalidAddressError
    false
  end

  def self.perform_additional_checks(ip)
    checks = []

    # Check for private IP addresses
    ip_addr = IPAddr.new(ip)
    if ip_addr.private?
      checks << { check: 'private_ip', passed: false, message: 'Private IP address detected' }
    else
      checks << { check: 'private_ip', passed: true }
    end

    # Check for localhost
    if ip == '127.0.0.1' || ip == '::1'
      checks << { check: 'localhost', passed: false, message: 'Localhost IP detected' }
    else
      checks << { check: 'localhost', passed: true }
    end

    # Check for suspicious patterns
    if ip.start_with?('192.168.', '10.', '172.16.', '172.17.', '172.18.', '172.19.', '172.20.', '172.21.', '172.22.', '172.23.', '172.24.', '172.25.', '172.26.', '172.27.', '172.28.', '172.29.', '172.30.', '172.31.')
      checks << { check: 'suspicious_pattern', passed: false, message: 'Suspicious IP pattern detected' }
    else
      checks << { check: 'suspicious_pattern', passed: true }
    end

    all_passed = checks.all? { |check| check[:passed] }

    {
      valid: all_passed,
      reason: all_passed ? 'All checks passed' : checks.find { |c| !c[:passed] }[:message],
      checks: checks
    }
  end

  def self.calculate_reputation_score(blacklist_entry)
    return 100 if blacklist_entry.nil?

    score = 100
    score -= 30 if blacklist_entry.permanent?
    score -= blacklist_entry.severity * 10
    score -= [blacklist_entry.block_count * 5, 50].min

    [score, 0].max
  end

  def self.calculate_risk_level(blacklist_entry)
    return 'low' if blacklist_entry.nil?

    if blacklist_entry.permanent? && blacklist_entry.severity >= 4
      'critical'
    elsif blacklist_entry.severity >= 3
      'high'
    elsif blacklist_entry.severity >= 2
      'medium'
    else
      'low'
    end
  end

  def self.generate_threat_indicators(blacklist_entry)
    indicators = []

    if blacklist_entry.nil?
      return ['none']
    end

    indicators << 'blacklisted' if blacklist_entry.active?
    indicators << 'permanent' if blacklist_entry.permanent?
    indicators << 'high_severity' if blacklist_entry.severity >= 3
    indicators << 'frequent_offender' if (blacklist_entry.block_count || 0) >= 5

    indicators
  end

  def self.clear_validation_cache(ip)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:validate:#{ip}",
      "#{CACHE_KEY_PREFIX}:reputation:#{ip}",
      "#{CACHE_KEY_PREFIX}:range:#{ip}",
      "#{CACHE_KEY_PREFIX}:geolocation:#{ip}",
      "#{CACHE_KEY_PREFIX}:threat_intel:#{ip}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end