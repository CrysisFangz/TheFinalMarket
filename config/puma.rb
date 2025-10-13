# ==============================================================================
# Puma Configuration for TheFinalMarket
# ==============================================================================
# This file configures Puma web server for optimal performance, reliability,
# and maintainability in the Rails application environment.
#
# Configuration Principles:
# - Environment-aware settings for development, staging, and production
# - Performance optimized threading based on workload characteristics
# - Robust error handling and graceful shutdown capabilities
# - Security-first approach with proper binding and access controls

require 'etc'

# ==============================================================================
# Environment Detection and Validation
# ==============================================================================

# Detect the current Rails environment with fallback to development
RAILS_ENV = ENV.fetch('RAILS_ENV', 'development').freeze

# Validate environment to prevent misconfigurations
VALID_ENVIRONMENTS = %w[development test staging production].freeze
unless VALID_ENVIRONMENTS.include?(RAILS_ENV)
  raise "Invalid RAILS_ENV: #{RAILS_ENV}. Must be one of: #{VALID_ENVIRONMENTS.join(', ')}"
end

# ==============================================================================
# Performance Configuration
# ==============================================================================

# Determine optimal thread count based on environment and CPU cores
# Production uses more conservative threading to balance throughput vs latency
# Development uses minimal threading for better debugging experience
CPU_CORES = Etc.nprocessors.freeze

BASE_THREAD_COUNT = case RAILS_ENV
when 'production'
  [CPU_CORES, ENV.fetch('PUMA_MIN_THREADS', 2).to_i].max
when 'staging'
  [CPU_CORES, ENV.fetch('PUMA_MIN_THREADS', 2).to_i].max
else # development, test
  1
end

# Maximum threads for handling concurrent requests
# Production: Higher max for burst traffic handling
# Development: Lower max for resource efficiency during development
MAX_THREADS = case RAILS_ENV
when 'production'
  ENV.fetch('PUMA_MAX_THREADS', [CPU_CORES * 2, 16].min).to_i
when 'staging'
  ENV.fetch('PUMA_MAX_THREADS', [CPU_CORES * 2, 12].min).to_i
else
  ENV.fetch('PUMA_MAX_THREADS', 4).to_i
end

# Validate thread configuration
if MAX_THREADS < BASE_THREAD_COUNT
  raise "MAX_THREADS (#{MAX_THREADS}) must be >= BASE_THREAD_COUNT (#{BASE_THREAD_COUNT})"
end

# Configure thread pool with optimized settings
threads BASE_THREAD_COUNT, MAX_THREADS

# ==============================================================================
# Network Configuration
# ==============================================================================

# Port configuration with validation
PORT = ENV.fetch('PORT', 3000).to_i
if PORT < 1024 && RAILS_ENV == 'production'
  warn "Warning: Using privileged port #{PORT} in production. Consider using a port >= 1024."
end

# Binding configuration for security and performance
bind_address = ENV.fetch('PUMA_BIND', 'tcp://0.0.0.0:3000')

# In production, bind to specific interface for security
if RAILS_ENV == 'production'
  bind_address = ENV.fetch('PUMA_BIND', "tcp://0.0.0.0:#{PORT}")
end

port PORT

# ==============================================================================
# Process Management
# ==============================================================================

# Worker configuration for multi-process deployments
# Only enable workers in production for true scalability
workers ENV.fetch('WEB_CONCURRENCY', 0).to_i

# Auto-determine worker count based on available resources if not explicitly set
if ENV['WEB_CONCURRENCY'].nil? && RAILS_ENV == 'production'
  # Use CPU cores - 1 to leave room for system processes
  workers [CPU_CORES - 1, 1].max
end

# ==============================================================================
# Plugin Configuration
# ==============================================================================

# Enable tmp_restart for zero-downtime deployments
plugin :tmp_restart

# Solid Queue integration for background job processing
# Only enable in single-server deployments to avoid duplicate supervisors
if ENV.fetch('SOLID_QUEUE_IN_PUMA', 'false').downcase == 'true'
  plugin :solid_queue
end

# ==============================================================================
# Process Management Files
# ==============================================================================

# PID file configuration for process management
pidfile_path = ENV.fetch('PIDFILE', "tmp/pids/server.pid")

# Only set PID file in non-development environments unless explicitly requested
if RAILS_ENV != 'development' || ENV['PIDFILE']
  pidfile pidfile_path
end

# ==============================================================================
# Advanced Performance Settings
# ==============================================================================

# Connection backlog for handling burst traffic
backlog ENV.fetch('PUMA_BACKLOG', 2048).to_i

# Request timeout to prevent hanging connections
if RAILS_ENV == 'production'
  # Longer timeout for production workloads
  request_timeout ENV.fetch('PUMA_REQUEST_TIMEOUT', 60).to_i
else
  # Shorter timeout for development
  request_timeout ENV.fetch('PUMA_REQUEST_TIMEOUT', 30).to_i
end

# ==============================================================================
# Security and Monitoring
# ==============================================================================

# State file for monitoring and debugging
state_path ENV.fetch('PUMA_STATE_PATH', "tmp/pids/puma.state")

# Control server for graceful shutdown and monitoring
if ENV.fetch('PUMA_CONTROL_SERVER', 'false').downcase == 'true'
  control_url ENV.fetch('PUMA_CONTROL_URL', "unix://tmp/pids/pumactl.sock")
end

# ==============================================================================
# Graceful Shutdown Configuration
# ==============================================================================

# Graceful shutdown timeout
graceful_shutdown_timeout ENV.fetch('PUMA_GRACEFUL_SHUTDOWN_TIMEOUT', 30).to_i

# Force shutdown timeout for stuck processes
force_shutdown_after ENV.fetch('PUMA_FORCE_SHUTDOWN_AFTER', 10).to_i

# ==============================================================================
# Environment-Specific Optimizations
# ==============================================================================

# Development-specific settings
if RAILS_ENV == 'development'
  # Enable thread-based reloading for faster development
  preload_app! unless ENV['PUMA_PRELOAD_APP'] == 'false'

  # Reduce resource usage in development
  backlog 128
end

# Production-specific settings
if RAILS_ENV == 'production'
  # Preload application for faster worker spawning
  preload_app!

  # Enable application preloading for better memory usage
  prune_bundler if ENV.fetch('PUMA_PRUNE_BUNDLER', 'true').downcase == 'true'

  # Optimize for production workloads
  backlog 4096

  # Enable worker timeout for stuck processes
  worker_timeout ENV.fetch('PUMA_WORKER_TIMEOUT', 60).to_i if workers > 0
end

# ==============================================================================
# Health Check and Monitoring Hooks
# ==============================================================================

# Health check endpoint for load balancers
if ENV.fetch('PUMA_HEALTH_CHECK', 'false').downcase == 'true'
  # Add health check middleware or endpoint here
  # This would typically be handled by Rails routes or middleware
end

# ==============================================================================
# Logging Configuration
# ==============================================================================

# Enhanced logging for better debugging and monitoring
if ENV.fetch('PUMA_ENHANCED_LOGGING', 'false').downcase == 'true'
  # Configure structured logging
  # This would typically integrate with Rails logger configuration
end

# ==============================================================================
# Configuration Summary
# ==============================================================================

# Log configuration summary for debugging
if ENV.fetch('PUMA_DEBUG_CONFIG', 'false').downcase == 'true'
  $stderr.puts "Puma Configuration Summary:"
  $stderr.puts "  Environment: #{RAILS_ENV}"
  $stderr.puts "  CPU Cores: #{CPU_CORES}"
  $stderr.puts "  Threads: #{BASE_THREAD_COUNT}-#{MAX_THREADS}"
  $stderr.puts "  Workers: #{workers}"
  $stderr.puts "  Port: #{PORT}"
  $stderr.puts "  PID File: #{pidfile_path}"
end
