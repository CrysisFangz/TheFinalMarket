# frozen_string_literal: true

# Rack::Attack Configuration
# Middleware for blocking & throttling abusive requests
#
# Documentation: https://github.com/rack/rack-attack

class Rack::Attack
  # Configure cache store for tracking requests
  # In production, use Redis for better performance across multiple servers
  Rack::Attack.cache.store = if Rails.env.production?
    ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
  else
    ActiveSupport::Cache::MemoryStore.new
  end

  ### Throttle Configuration ###

  # Throttle all requests by IP (general protection)
  # Limit: 300 requests per 5 minutes
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets')
  end

  # Throttle login attempts by IP address
  # Limit: 5 attempts per 20 seconds
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/login' && req.post?
      req.ip
    end
  end

  # Throttle login attempts by email address
  # Limit: 5 attempts per 20 seconds per email
  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/login' && req.post?
      # Extract email from POST parameters
      req.params['email'].to_s.downcase.gsub(/\s+/, '')
    end
  end

  # Throttle signup attempts
  # Limit: 3 signups per hour per IP
  throttle('signups/ip', limit: 3, period: 1.hour) do |req|
    if req.path == '/signup' && req.post?
      req.ip
    end
  end

  # Throttle password reset requests
  # Limit: 3 requests per hour per IP
  throttle('password_resets/ip', limit: 3, period: 1.hour) do |req|
    if req.path.include?('password/reset') && req.post?
      req.ip
    end
  end

  # Throttle API requests by API key or IP
  # Limit: 100 requests per 15 minutes
  throttle('api/ip', limit: 100, period: 15.minutes) do |req|
    if req.path.start_with?('/api/')
      req.ip
    end
  end

  # Throttle search requests (prevent scraping)
  # Limit: 30 searches per minute
  throttle('search/ip', limit: 30, period: 1.minute) do |req|
    if req.path.include?('search') || req.path.include?('products')
      req.ip
    end
  end

  # Throttle order creation (prevent abuse)
  # Limit: 10 orders per hour per user
  throttle('orders/user', limit: 10, period: 1.hour) do |req|
    if req.path == '/orders' && req.post?
      # Track by user_id if authenticated, otherwise by IP
      if req.env['warden']&.user
        "user-#{req.env['warden'].user.id}"
      else
        req.ip
      end
    end
  end

  ### Blocklist Configuration ###

  # Block requests from specific IPs (maintain in database or environment)
  blocklist('block suspicious IPs') do |req|
    # Check if IP is in blocklist
    # In production, move this to Redis or database
    blocked_ips = ENV.fetch('BLOCKED_IPS', '').split(',').map(&:strip)
    blocked_ips.include?(req.ip)
  end

  # Block requests with suspicious patterns
  blocklist('block suspicious requests') do |req|
    # Block common exploit attempts
    suspicious_patterns = [
      /eval\(/i,
      /base64_decode/i,
      /system\(/i,
      /exec\(/i,
      /<script/i,
      /javascript:/i,
      /\.\.\/\.\.\//,  # Path traversal
      /union.*select/i, # SQL injection
      /concat.*char/i   # SQL injection
    ]

    path_and_query = "#{req.path}#{req.query_string}"
    suspicious_patterns.any? { |pattern| path_and_query.match?(pattern) }
  end

  ### Safelist Configuration ###

  # Allow specific IPs (admin, monitoring services, etc.)
  safelist('allow from trusted IPs') do |req|
    # Whitelist localhost and private networks in development
    if Rails.env.development?
      ['127.0.0.1', '::1', 'localhost'].include?(req.ip)
    else
      # In production, whitelist specific monitoring/admin IPs
      trusted_ips = ENV.fetch('TRUSTED_IPS', '').split(',').map(&:strip)
      trusted_ips.include?(req.ip)
    end
  end

  # Allow health check endpoints
  safelist('allow health checks') do |req|
    req.path == '/health' || req.path == '/health_check'
  end

  ### Custom Responses ###

  # Customize throttled response
  self.throttled_responder = lambda do |env|
    match_data = env['rack.attack.match_data']
    now = match_data[:epoch_time]
    period = match_data[:period]
    limit = match_data[:limit]
    
    headers = {
      'Content-Type' => 'application/json',
      'X-RateLimit-Limit' => limit.to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + period).to_s
    }

    [429, headers, [{ 
      error: 'Rate limit exceeded',
      message: 'Too many requests. Please try again later.',
      retry_after: period
    }.to_json]]
  end

  # Customize blocked response
  self.blocklisted_responder = lambda do |env|
    [403, {'Content-Type' => 'application/json'}, [{ 
      error: 'Forbidden',
      message: 'Your request has been blocked.'
    }.to_json]]
  end

  ### Logging ###

  # Log blocked requests
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    
    if [:throttle, :blocklist].include?(req.env['rack.attack.match_type'])
      Rails.logger.warn({
        event: 'RACK_ATTACK',
        match_type: req.env['rack.attack.match_type'],
        match_discriminator: req.env['rack.attack.match_discriminator'],
        ip: req.ip,
        path: req.path,
        user_agent: req.user_agent,
        timestamp: Time.current
      }.to_json)
    end
  end

  ### Fail2Ban-style Blocking ###

  # Block IPs after too many failed login attempts
  # Stores IPs in cache for 1 hour
  Rack::Attack.blocklist('fail2ban pentesters') do |req|
    # Count failed login attempts for this IP
    Rack::Attack::Fail2Ban.filter("pentest-#{req.ip}", maxretry: 10, findtime: 10.minutes, bantime: 1.hour) do
      # Return true for any successful login attempt to reset counter
      # Return false for failed attempts to increment counter
      req.path == '/login' && req.post?
    end
  end
end

# Enable Rack::Attack in the application
Rails.application.config.middleware.use Rack::Attack unless Rails.env.test?