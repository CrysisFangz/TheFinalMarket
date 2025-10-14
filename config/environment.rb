# ==============================================================================
# Rails Application Environment Configuration
# ==============================================================================
# This file serves as the central entry point for the Rails application lifecycle.
# It orchestrates the loading and initialization of the entire application stack,
# ensuring proper configuration, dependency resolution, and environment setup.
#
# CRITICAL PATH: Application Bootstrap Sequence
# 1. Load application configuration and dependencies
# 2. Validate environment and security constraints
# 3. Initialize Rails application with optimized settings
# 4. Configure performance and monitoring systems
# ==============================================================================

require_relative "application"

# ==============================================================================
# Environment Validation and Security Checks
# ==============================================================================
# Perform pre-initialization validation to ensure the application can start
# safely and efficiently. This prevents runtime failures and security issues.

begin
  # Validate Rails Environment Configuration
  unless defined?(Rails) && Rails.application
    raise StandardError, "Rails application configuration not properly loaded"
  end

  # Environment-specific security validations
  if Rails.env.production?
    # Production Security Checklist
    required_env_vars = [
      'DATABASE_URL',
      'SECRET_KEY_BASE',
      'RAILS_MASTER_KEY'
    ]

    missing_vars = required_env_vars.select { |var| ENV[var].blank? }
    if missing_vars.any?
      raise SecurityError, "Missing required environment variables: #{missing_vars.join(', ')}"
    end

    # Validate SSL enforcement in production
    unless Rails.application.config.force_ssl
      Rails.logger.warn "SSL enforcement not enabled in production environment"
    end
  end

  # Performance Pre-initialization
  # Configure memory and performance settings before full initialization
  if Rails.env.production?
    # Enable GC optimization for production workloads
    GC::Profiler.enable if ENV['ENABLE_GC_PROFILING'] == 'true'

    # Configure database connection pool based on environment
    if ENV['DATABASE_POOL_SIZE']
      ActiveRecord::Base.connection_pool.instance_variable_set(
        :@size, ENV['DATABASE_POOL_SIZE'].to_i
      )
    end
  end

  # ==============================================================================
  # Rails Application Initialization
  # ==============================================================================
  # Initialize the Rails application with comprehensive error handling and
  # performance monitoring. This is the critical bootstrap process that
  # brings the entire application stack online.

  Rails.application.initialize!

  # ==============================================================================
  # Post-Initialization Configuration and Monitoring
  # ==============================================================================
  # Perform post-initialization setup, monitoring configuration, and
  # final validation checks to ensure optimal application performance.

  if Rails.env.production?
    # Initialize application performance monitoring
    Rails.logger.info "Application initialized successfully in #{Rails.env} environment"

    # Validate critical application components
    unless ActiveRecord::Base.connected?
      raise StandardError, "Database connection not established after initialization"
    end

    # Log application configuration summary
    config_summary = {
      rails_version: Rails.version,
      ruby_version: RUBY_VERSION,
      environment: Rails.env,
      database_adapter: ActiveRecord::Base.connection.adapter_name,
      timezone: Time.zone.name,
      locale: I18n.locale
    }

    Rails.logger.info "Application Configuration: #{config_summary.inspect}"

    # Initialize background job monitoring if applicable
    if defined?(ActiveJob) && Rails.application.config.active_job.queue_adapter != :inline
      Rails.logger.info "Background job processing enabled with #{Rails.application.config.active_job.queue_adapter} adapter"
    end
  end

rescue StandardError => e
  # ==============================================================================
  # Comprehensive Error Handling and Recovery
  # ==============================================================================
  # Provide detailed error information for debugging while maintaining security

  error_details = {
    error_class: e.class.name,
    message: e.message,
    backtrace: Rails.env.development? ? e.backtrace&.first(10) : nil,
    environment: Rails.env,
    timestamp: Time.current.iso8601
  }

  Rails.logger.fatal "CRITICAL: Application initialization failed - #{error_details.inspect}"

  # In production, avoid exposing sensitive error details
  if Rails.env.production?
    error_message = "Application failed to start. Please check system logs for details."
  else
    error_message = "Application initialization failed: #{e.message}"
  end

  # Attempt graceful shutdown if possible
  if defined?(Rails) && Rails.application
    Rails.application.executor.wrap do
      # Perform any cleanup operations here
      Rails.logger.info "Attempting graceful shutdown after initialization failure"
    end
  end

  # Re-raise the exception to prevent application from starting in a broken state
  raise e

rescue SecurityError => e
  # Handle security-related errors with enhanced logging
  Rails.logger.fatal "SECURITY ERROR: #{e.message}"
  Rails.logger.fatal "Application startup blocked due to security configuration issues"

  # Always re-raise security errors to prevent insecure application startup
  raise e

ensure
  # ==============================================================================
  # Cleanup and Finalization
  # ==============================================================================
  # Ensure proper cleanup regardless of initialization success or failure

  if defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?
    # Ensure database connections are properly configured
    ActiveRecord::Base.connection_pool.disconnect! if Rails.env.test?
  end

  # Log final initialization status
  if Rails.application&.initialized?
    Rails.logger.info "✓ Rails application initialization completed successfully"
  else
    Rails.logger.error "✗ Rails application initialization failed or incomplete"
  end
end
