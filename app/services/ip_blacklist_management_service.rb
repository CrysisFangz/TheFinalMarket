class IpBlacklistManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'ip_blacklist_management'
  CACHE_TTL = 10.minutes

  def self.check_blacklisted(ip)
    cache_key = "#{CACHE_KEY_PREFIX}:blacklisted:#{ip}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('ip_blacklist_management') do
        with_retry do
          result = IpBlacklist.active.exists?(ip_address: ip)

          EventPublisher.publish('ip_blacklist.checked', {
            ip_address: ip,
            is_blacklisted: result,
            checked_at: Time.current
          })

          result
        end
      end
    end
  end

  def self.add_to_blacklist(ip, reason, severity: 1, duration: nil, added_by: nil)
    cache_key = "#{CACHE_KEY_PREFIX}:add:#{ip}:#{reason}:#{severity}:#{duration}:#{added_by}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('ip_blacklist_management') do
        with_retry do
          expires_at = duration ? duration.from_now : nil
          permanent = duration.nil?

          blacklist_entry = IpBlacklist.create!(
            ip_address: ip,
            reason: reason,
            severity: severity,
            expires_at: expires_at,
            permanent: permanent,
            added_by: added_by
          )

          # Clear related caches
          clear_ip_cache(ip)

          EventPublisher.publish('ip_blacklist.added', {
            blacklist_id: blacklist_entry.id,
            ip_address: ip,
            reason: reason,
            severity: severity,
            expires_at: expires_at,
            permanent: permanent,
            added_by: added_by,
            added_at: Time.current
          })

          blacklist_entry
        end
      end
    end
  end

  def self.remove_from_blacklist(ip)
    cache_key = "#{CACHE_KEY_PREFIX}:remove:#{ip}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('ip_blacklist_management') do
        with_retry do
          blacklist_entry = IpBlacklist.find_by(ip_address: ip)
          if blacklist_entry
            blacklist_entry.destroy

            # Clear related caches
            clear_ip_cache(ip)

            EventPublisher.publish('ip_blacklist.removed', {
              blacklist_id: blacklist_entry.id,
              ip_address: ip,
              reason: blacklist_entry.reason,
              removed_at: Time.current
            })
          end

          blacklist_entry
        end
      end
    end
  end

  def self.get_blacklist_entries(filters = {})
    cache_key = "#{CACHE_KEY_PREFIX}:entries:#{filters.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('ip_blacklist_management') do
        with_retry do
          query = IpBlacklist.all

          query = query.where(permanent: filters[:permanent]) if filters[:permanent].present?
          query = query.where('severity >= ?', filters[:min_severity]) if filters[:min_severity].present?
          query = query.where('created_at >= ?', filters[:since]) if filters[:since].present?
          query = query.where(added_by: filters[:added_by]) if filters[:added_by].present?

          query = query.includes(:added_by_user) if filters[:include_user]

          entries = query.order(created_at: :desc).to_a

          EventPublisher.publish('ip_blacklist.entries_retrieved', {
            filters: filters,
            entries_count: entries.count,
            retrieved_at: Time.current
          })

          entries
        end
      end
    end
  end

  def self.get_blacklisted_ips
    cache_key = "#{CACHE_KEY_PREFIX}:blacklisted_ips"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      with_circuit_breaker('ip_blacklist_management') do
        with_retry do
          IpBlacklist.active.pluck(:ip_address)
        end
      end
    end
  end

  def self.process_expired_entries
    cache_key = "#{CACHE_KEY_PREFIX}:process_expired"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('ip_blacklist_management') do
        with_retry do
          expired_entries = IpBlacklist.where('expires_at IS NOT NULL AND expires_at <= ?', Time.current)

          removed_count = 0
          expired_entries.each do |entry|
            entry.destroy
            clear_ip_cache(entry.ip_address)
            removed_count += 1
          end

          EventPublisher.publish('ip_blacklist.expired_entries_processed', {
            processed_count: removed_count,
            processed_at: Time.current
          })

          removed_count
        end
      end
    end
  end

  def self.get_blacklist_stats
    cache_key = "#{CACHE_KEY_PREFIX}:stats"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      with_circuit_breaker('ip_blacklist_management') do
        with_retry do
          total_entries = IpBlacklist.count
          active_entries = IpBlacklist.active.count
          permanent_entries = IpBlacklist.permanent.count
          temporary_entries = IpBlacklist.temporary.count

          severity_distribution = IpBlacklist.group(:severity).count

          {
            total_entries: total_entries,
            active_entries: active_entries,
            permanent_entries: permanent_entries,
            temporary_entries: temporary_entries,
            severity_distribution: severity_distribution,
            generated_at: Time.current
          }
        end
      end
    end
  end

  private

  def self.clear_ip_cache(ip)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:blacklisted:#{ip}",
      "#{CACHE_KEY_PREFIX}:add:#{ip}",
      "#{CACHE_KEY_PREFIX}:remove:#{ip}",
      "#{CACHE_KEY_PREFIX}:blacklisted_ips"
    ]

    Rails.cache.delete_multi(cache_keys)
  end

  def self.clear_management_cache
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:blacklisted_ips",
      "#{CACHE_KEY_PREFIX}:stats",
      "#{CACHE_KEY_PREFIX}:process_expired"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end