# frozen_string_literal: true

# TheFinalMarket Rails Application Bootstrap
# =============================================================================
# This file initializes the Rails application environment with enterprise-grade
# error handling, performance optimizations, and security considerations.
#
# Core Responsibilities:
# - Environment configuration and validation
# - Gem dependency management via Bundler
# - Performance optimization via Bootsnap caching
# - Comprehensive error handling and logging
# - Security hardening for production deployments

require "pathname"
require "logger"

module RailsBoot
  # Configuration constants for enhanced maintainability
  GEMFILE_PATH = "../Gemfile"
  BOOTSNAP_CACHE_DIR = Pathname.new(__dir__).join("../tmp/cache/bootsnap")
  REQUIRED_RUBY_VERSION = "3.2.0"
  SUPPORTED_RAILS_VERSIONS = [">= 7.0.0", "< 8.0.0"].freeze

  class << self
    # Comprehensive application bootstrap with error handling
    def initialize_application
      validate_environment
      setup_bundler_configuration
      validate_gemfile_integrity
      initialize_performance_optimizations
      log_bootstrap_completion
    rescue StandardError => e
      handle_bootstrap_error(e)
    end

    private

    # Validate Ruby and Rails environment compatibility
    def validate_environment
      validate_ruby_version
      # Rails version validation moved to after Bundler loads
      validate_critical_paths
      validate_environment_variables
    end

    def validate_ruby_version
      current_version = RUBY_VERSION
      required_version = Gem::Version.new(REQUIRED_RUBY_VERSION)

      unless Gem::Version.new(current_version) >= required_version
        raise BootstrapError,
          "Ruby version #{current_version} is below minimum required #{REQUIRED_RUBY_VERSION}"
      end
    end

    def validate_rails_version
      # This validation runs after Bundler loads Rails (if needed)
      # Skipped during initial boot to avoid circular dependency
      return unless defined?(Rails::VERSION)
      
      rails_version = Gem::Version.new(Rails::VERSION::STRING)
      SUPPORTED_RAILS_VERSIONS.each do |requirement|
        unless Gem::Requirement.new(requirement).satisfied_by?(rails_version)
          raise BootstrapError,
            "Rails version #{Rails::VERSION::STRING} does not meet requirement #{requirement}"
        end
      end
    end

    def validate_critical_paths
      gemfile_path = Pathname.new(__dir__).join(GEMFILE_PATH)
      unless gemfile_path.exist?
        raise BootstrapError,
          "Gemfile not found at #{gemfile_path}. Application structure may be corrupted."
      end

      unless gemfile_path.readable?
        raise BootstrapError,
          "Gemfile at #{gemfile_path} is not readable. Check file permissions."
      end
    end

    def validate_environment_variables
      # Validate critical environment variables for production
      if production_environment?
        validate_production_environment_variables
      end
    end

    def validate_production_environment_variables
      critical_vars = %w[DATABASE_URL SECRET_KEY_BASE]
      missing_vars = critical_vars.select { |var| ENV[var].nil? || ENV[var].empty? }

      unless missing_vars.empty?
        raise BootstrapError,
          "Missing critical environment variables in production: #{missing_vars.join(", ")}"
      end
    end

    def production_environment?
      ENV["RAILS_ENV"] == "production" || ENV["RACK_ENV"] == "production"
    end

    # Configure Bundler with enhanced error handling
    def setup_bundler_configuration
      # Set Gemfile path with validation
      gemfile_path = Pathname.new(__dir__).join(GEMFILE_PATH).expand_path
      ENV["BUNDLE_GEMFILE"] ||= gemfile_path.to_s

      # Validate and require bundler setup
      begin
        require "bundler/setup"
      rescue LoadError => e
        raise BootstrapError,
          "Bundler not available. Install bundler gem: gem install bundler. Original error: #{e.message}"
      end

      # Configure bundler settings for production optimization
      configure_bundler_settings if production_environment?
    end

    def configure_bundler_settings
      # Disable rubygems fallback in production for security
      ENV["BUNDLE_DISABLE_SHARED_GEMS"] = "true"

      # Enable frozen deployment for reproducible builds
      ENV["BUNDLE_DEPLOYMENT"] = "true"

      # Configure conservative updating for stability
      ENV["BUNDLE_CONSERVATIVE_UPDATING"] = "true"
    end

    # Validate Gemfile integrity and lock file consistency
    def validate_gemfile_integrity
      gemfile_path = Pathname.new(__dir__).join(GEMFILE_PATH)
      lockfile_path = gemfile_path.sub_ext(".lock")

      if lockfile_path.exist?
        validate_gemfile_lock_consistency(gemfile_path, lockfile_path)
      else
        warn("Gemfile.lock not found. Run 'bundle install' to generate.")
      end
    end

    def validate_gemfile_lock_consistency(gemfile_path, lockfile_path)
      gemfile_mtime = gemfile_path.mtime
      lockfile_mtime = lockfile_path.mtime

      if lockfile_mtime < gemfile_mtime
        warn("Gemfile.lock is older than Gemfile. Consider running 'bundle update' to ensure consistency.")
      end
    rescue Errno::ENOENT
      # File may have been deleted between check and access
      warn("Could not validate Gemfile.lock consistency due to missing file")
    end

    # Initialize performance optimizations with environment awareness
    def initialize_performance_optimizations
      return unless performance_optimizations_enabled?

      begin
        require_bootsnap_with_validation
        configure_bootsnap_cache
      rescue LoadError => e
        Rails.logger.warn("Bootsnap not available for performance optimization: #{e.message}")
      rescue StandardError => e
        Rails.logger.error("Failed to initialize Bootsnap: #{e.message}")
        # Continue without Bootsnap rather than failing completely
      end
    end

    def performance_optimizations_enabled?
      # Enable in development and production, disable in test for faster test runs
      !test_environment? && bootsnap_available?
    end

    def test_environment?
      ENV["RAILS_ENV"] == "test" || ENV["RACK_ENV"] == "test"
    end

    def bootsnap_available?
      # Check if bootsnap gem is available without loading it
      Gem::Specification.find_by_name("bootsnap")
    rescue Gem::LoadError
      false
    end

    def require_bootsnap_with_validation
      require "bootsnap/setup"

      # Validate bootsnap cache directory
      unless BOOTSNAP_CACHE_DIR.exist?
        BOOTSNAP_CACHE_DIR.mkdir(parents: true)
        Rails.logger.info("Created Bootsnap cache directory: #{BOOTSNAP_CACHE_DIR}")
      end
    end

    def configure_bootsnap_cache
      # Configure bootsnap for optimal performance
      Bootsnap.setup(
        cache_dir: BOOTSNAP_CACHE_DIR,
        development_mode: development_environment?,
        load_path_cache: true,
        compile_cache_iseq: true,
        compile_cache_yaml: true
      )
    end

    def development_environment?
      ENV["RAILS_ENV"] == "development" || ENV["RACK_ENV"] == "development"
    end

    # Logging and monitoring
    def log_bootstrap_completion
      # Only log if Rails is loaded
      return unless defined?(Rails)
      
      Rails.logger.info("Rails application bootstrap completed successfully") if Rails.logger
      Rails.logger.info("Environment: #{Rails.env}") if Rails.logger
      Rails.logger.info("Ruby version: #{RUBY_VERSION}") if Rails.logger
      Rails.logger.info("Rails version: #{Rails::VERSION::STRING}") if Rails.logger && defined?(Rails::VERSION)
    end

    def handle_bootstrap_error(error)
      error_message = "Rails application bootstrap failed: #{error.message}"
      
      # Use basic output if Rails logger is not available
      if defined?(Rails) && Rails.logger
        Rails.logger.error(error_message)
        Rails.logger.error(error.backtrace&.join("\n"))
      else
        warn(error_message)
        warn(error.backtrace&.join("\n")) if error.backtrace
      end

      # In production, we might want to exit gracefully rather than crash
      if production_environment?
        if defined?(Rails) && Rails.logger
          Rails.logger.fatal("Production bootstrap failure. Application cannot start.")
        else
          warn("Production bootstrap failure. Application cannot start.")
        end
        exit(1)
      else
        # In development, re-raise for debugging
        raise error
      end
    end
  end

  # Custom error class for bootstrap-specific errors
  class BootstrapError < StandardError; end
end

# Initialize the application
RailsBoot.initialize_application
