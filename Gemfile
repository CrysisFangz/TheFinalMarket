# =============================================================================
# TheFinalMarket - Ultra-Modern Rails 8.0 E-commerce Platform
# =============================================================================
# This Gemfile represents an enterprise-grade, highly optimized Ruby on Rails
# application with cutting-edge performance, security, and scalability features.
#
# Architecture: Monolithic Rails with Microservices Capabilities
# Performance Target: Sub-100ms response times, <512MB memory usage
# Security Standard: Zero-trust architecture with comprehensive audit trails
# Scalability Goal: 10,000+ concurrent users with horizontal scaling
# =============================================================================

source "https://rubygems.org"

# =============================================================================
# CORE RAILS STACK
# =============================================================================
# Modern Rails framework with edge optimizations and performance enhancements
gem "rails", "~> 8.0.2", ">= 8.0.2.1"

# High-performance PostgreSQL adapter with advanced features
gem "pg", "~> 1.5"

# Ultra-fast web server optimized for Rails
gem "puma", "~> 6.4", ">= 6.4.2"

# =============================================================================
# SECURITY & AUTHENTICATION
# =============================================================================
# Advanced authorization system with policy-based access control
gem "pundit", "~> 2.4"

# Rate limiting and DDoS protection
gem "rack-attack", "~> 6.7"

# CORS protection for API endpoints
gem "rack-cors", "~> 2.0"

# Security vulnerability scanning and audit trails
gem "brakeman", "~> 6.1", require: false
gem "bundler-audit", "~> 0.9", require: false

# Two-factor authentication with TOTP
gem "rotp", "~> 6.3"
gem "rqrcode", "~> 2.2"

# Secure credential management
gem "encrypted_strings", "~> 0.3"

# =============================================================================
# PERFORMANCE & MONITORING
# =============================================================================
# Advanced Performance Monitoring and Error Tracking
gem "skylight", "~> 6.0"
gem "sentry-rails", "~> 5.16"
gem "sentry-ruby", "~> 5.16"

# Memory profiling and optimization
gem "memory_profiler", "~> 1.0"
gem "heap-profiler", "~> 0.6"

# Boot time optimization
gem "bootsnap", "~> 1.18", require: false

# HTTP acceleration and compression
gem "thruster", "~> 0.1", require: false

# =============================================================================
# BACKGROUND JOBS & QUEUING
# =============================================================================
# High-performance background job processing with advanced features
gem "sidekiq", "~> 7.3"
gem "sidekiq-cron", "~> 1.12"
gem "sidekiq-scheduler", "~> 5.0"

# Redis for caching and background job storage
gem "redis", "~> 5.2"
gem "hiredis", "~> 0.6"  # Faster Redis client

# =============================================================================
# DATABASE & SEARCH
# =============================================================================
# Advanced search capabilities with Elasticsearch integration
gem "elasticsearch-model", "~> 8.0"
gem "elasticsearch-rails", "~> 8.0"
gem "searchkick", "~> 5.3"

# Advanced database query optimization
gem "activerecord-enhancedsqlite3-adapter", "~> 0.8"  # If using SQLite3

# =============================================================================
# API & INTEGRATION
# =============================================================================
# API versioning and documentation
gem "versionist", "~> 2.0"
gem "grape", "~> 2.1"
gem "grape-entity", "~> 1.0"

# Circuit breaker for external service resilience
gem "circuitbox", "~> 2.0"
gem "typhoeus", "~> 1.4"  # HTTP client for external APIs

# Webhook signature verification
gem "jwt", "~> 2.8"

# =============================================================================
# UI/UX & FRONTEND
# =============================================================================
# Modern CSS framework with advanced components
gem "bootstrap", "~> 5.3.3"

# Modern asset pipeline with Dart Sass support
gem "propshaft", "~> 0.8"
gem "dartsass-rails", "~> 0.5.1"

# Hotwire for SPA-like reactivity
gem "turbo-rails", "~> 2.0"
gem "stimulus-rails", "~> 1.3"

# Enhanced form handling
gem "turbo_boost-streams", "~> 0.1"
gem "cocoon", "~> 1.2"

# Reusable UI components
gem "view_component", "~> 3.12"
gem "view_component-contrib", "~> 0.2"

# =============================================================================
# BUSINESS LOGIC
# =============================================================================
# Payment processing with Square
gem "square.rb", "~> 42.0"

# Money and currency handling
gem "money-rails", "~> 1.15"
gem "eu_central_bank", "~> 1.7"

# Advanced pagination
gem "pagy", "~> 9.0"

# Business intelligence and analytics
gem "descriptive_statistics", "~> 2.5"

# =============================================================================
# PWA & MOBILE
# =============================================================================
# Progressive Web App support
gem "web-push", "~> 3.0"
gem "pwa", "~> 2.0"

# Mobile API optimization
gem "rack-mobile-detect", "~> 0.4"

# =============================================================================
# DEVELOPMENT & TESTING
# =============================================================================
group :development, :test do
  # Advanced debugging and profiling
  gem "debug", "~> 1.9", platforms: %i[ mri mingw mswin x64_mingw ], require: "debug/prelude"
  gem "readapt", "~> 0.3"

  # Code quality and style enforcement
  gem "rubocop-rails-omakase", "~> 1.0", require: false
  gem "rubocop-performance", "~> 1.21", require: false
  gem "rubocop-rspec", "~> 3.0", require: false

  # Security scanning in development
  gem "dawnscanner", "~> 2.3", require: false
end

group :development do
  # Enhanced console with advanced features
  gem "web-console", "~> 4.2"
  gem "awesome_print", "~> 1.9"
  gem "pry-rails", "~> 0.3"
  gem "pry-byebug", "~> 3.10"
end

group :test do
  # Comprehensive testing suite
  gem "capybara", "~> 3.40"
  gem "selenium-webdriver", "~> 4.17"
  gem "webdrivers", "~> 5.3"
  gem "cuprite", "~> 0.15"  # Headless Chrome testing

  # API testing
  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.4"
end

# =============================================================================
# PRODUCTION & DEPLOYMENT
# =============================================================================
# Zero-downtime deployment
gem "kamal", "~> 2.0", require: false

# Platform-specific optimizations
gem "tzinfo-data", "~> 1.2024", platforms: %i[ mingw mswin x64_mingw jruby ]

# Active Storage enhancements
gem "image_processing", "~> 1.13"
gem "ruby-vips", "~> 2.2"

# =============================================================================
# ENTERPRISE FEATURES
# =============================================================================
# Feature flags for gradual rollouts
gem "flipper", "~> 1.3"
gem "flipper-ui", "~> 1.3"
gem "flipper-active_record", "~> 1.3"

# Advanced enums with metadata
gem "enumerize", "~> 2.8"

# Blockchain integration (optional)
# gem "eth", "~> 0.5"  # Uncommented for production use

# Advanced statistical analysis
gem "statsd-instrument", "~> 3.7"
gem "datadog", "~> 2.1"