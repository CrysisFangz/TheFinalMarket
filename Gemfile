# =============================================================================
# TheFinalMarket - Ultra-Modern Rails 8.0 E-commerce Platform
# =============================================================================
# This Gemfile represents an enterprise-grade, highly optimized Ruby on Rails
# application with cutting-edge performance, security, and scalability features.
#
# Architecture: Monolithic Rails with Microservices Capabilities
# Performance Target: Sub-50ms response times, <256MB memory usage
# Security Standard: Zero-trust architecture with comprehensive audit trails
# Scalability Goal: 50,000+ concurrent users with horizontal scaling
# Monitoring: Real-time performance and error tracking
# =============================================================================

source "https://rubygems.org"

# =============================================================================
# CORE RAILS STACK - Latest stable versions for maximum performance
# =============================================================================
# Modern Rails framework with edge optimizations and performance enhancements
gem "rails", "~> 8.0.2", ">= 8.0.2.1"

# High-performance PostgreSQL adapter with advanced features and query optimization
gem "pg", "~> 1.6"

# Ultra-fast web server optimized for Rails with advanced clustering
gem "puma", "~> 7.0", ">= 7.0.3"

# =============================================================================
# SECURITY & AUTHENTICATION - Enterprise-grade security suite
# =============================================================================
# Advanced authorization system with policy-based access control
gem "pundit", "~> 2.5"

# Rate limiting and DDoS protection with advanced threat detection
gem "rack-attack", "~> 6.7"

# CORS protection for API endpoints with fine-grained control
gem "rack-cors", "~> 2.0"

# Security vulnerability scanning and audit trails
gem "brakeman", "~> 7.1", require: false
gem "bundler-audit", "~> 0.9", require: false

# Database-level security and safe migrations
gem "strong_migrations", "~> 2.0"
gem "active_record_doctor", "~> 1.13", require: false

# Two-factor authentication with TOTP and advanced security features
gem "rotp", "~> 6.3"
gem "rqrcode", "~> 2.2"

# Secure credential management with encryption at rest
gem "encrypted_strings", "~> 0.3"
gem "lockbox", "~> 1.3"  # Additional encryption utilities

# =============================================================================
# PERFORMANCE & MONITORING - Advanced observability stack
# =============================================================================
# Production-ready performance monitoring with detailed insights
gem "skylight", "~> 6.0"
gem "sentry-rails", "~> 5.20"
gem "sentry-ruby", "~> 5.20"

# Memory profiling and optimization with leak detection
gem "memory_profiler", "~> 1.0"
gem "heap-profiler", "~> 0.6"
gem "derailed_benchmarks", "~> 2.1", require: false

# Boot time optimization with advanced caching strategies
gem "bootsnap", "~> 1.18", require: false

# HTTP acceleration and compression with edge caching
gem "thruster", "~> 0.1", require: false

# Development performance monitoring
gem "rack-mini-profiler", "~> 3.3", require: false

# =============================================================================
# BACKGROUND JOBS & QUEUING - High-throughput job processing
# =============================================================================
# High-performance background job processing with advanced features
gem "sidekiq", "~> 7.3"
gem "sidekiq-cron", "~> 1.12"

# Redis for caching and background job storage with clustering support
gem "redis", "~> 5.4"
gem "hiredis", "~> 0.6"  # Faster Redis client

# Rails 8 optimized job system with advanced monitoring
gem "solid_queue", "~> 1.2"
gem "mission_control-jobs", "~> 0.3"

# =============================================================================
# DATABASE & SEARCH - Advanced data layer optimization
# =============================================================================
# Advanced search capabilities with Elasticsearch integration
gem "elasticsearch-model", "~> 8.0"
gem "elasticsearch-rails", "~> 8.0"
gem "searchkick", "~> 5.4"

# Database query optimization and health monitoring
gem "activerecord-enhancedsqlite3-adapter", "~> 0.8"  # If using SQLite3
gem "database_consistency", "~> 1.7", require: false

# Advanced caching strategies
gem "solid_cache", "~> 1.0"

# =============================================================================
# API & INTEGRATION - Robust external service integration
# =============================================================================
# API versioning and documentation with OpenAPI 3.0 support
gem "versionist", "~> 2.0"
gem "grape", "~> 2.1"
gem "grape-entity", "~> 1.0"
gem "grape-swagger", "~> 2.1"

# Circuit breaker for external service resilience with advanced patterns
gem "circuitbox", "~> 2.0"
gem "typhoeus", "~> 1.4"  # HTTP client for external APIs
gem "httparty", "~> 0.22"  # Alternative HTTP client with better error handling

# Webhook signature verification with multiple algorithm support
gem "jwt", "~> 2.10"

# Health checks for external services
gem "health_check", "~> 3.1"
gem "okcomputer", "~> 1.18"

# =============================================================================
# UI/UX & FRONTEND - Modern, accessible, high-performance frontend
# =============================================================================
# Modern CSS framework with advanced components and accessibility features
gem "bootstrap", "~> 5.3.5"

# Modern asset pipeline with Dart Sass support and advanced optimization
gem "propshaft", "~> 1.2"
gem "dartsass-rails", "~> 0.5.1"

# Hotwire for SPA-like reactivity with enhanced performance
gem "turbo-rails", "~> 2.0"
gem "stimulus-rails", "~> 1.3"

# Enhanced form handling with real-time validation
gem "turbo_boost-streams", "~> 0.1"
gem "cocoon", "~> 1.2"

# Reusable UI components with advanced theming
gem "view_component", "~> 3.23"
gem "view_component-contrib", "~> 0.2"

# Advanced CSS processing and optimization
gem "cssbundling-rails", "~> 1.4"
gem "jsbundling-rails", "~> 1.3"

# =============================================================================
# BUSINESS LOGIC - Enterprise-grade business features
# =============================================================================
# Payment processing with Square and advanced fraud detection
gem "square.rb", "~> 42.2"

# Money and currency handling with multi-currency support
gem "money-rails", "~> 1.15"
gem "eu_central_bank", "~> 1.7"

# Advanced pagination with SEO optimization
gem "pagy", "~> 9.1"

# Business intelligence and analytics with real-time processing
gem "descriptive_statistics", "~> 2.5"

# Advanced search and filtering
gem "ransack", "~> 4.3"

# =============================================================================
# PWA & MOBILE - Progressive Web App and mobile optimization
# =============================================================================
# Progressive Web App support with advanced caching strategies
gem "web-push", "~> 3.0"
gem "pwa", "~> 2.0"

# Mobile API optimization with device detection
gem "rack-mobile-detect", "~> 0.4"
gem "mobile-fu", "~> 1.4"

# =============================================================================
# DEVELOPMENT & TESTING - Comprehensive development toolkit
# =============================================================================
group :development, :test do
  # Advanced debugging and profiling with enhanced introspection
  gem "debug", "~> 1.11", platforms: %i[ mri mingw mswin x64_mingw ], require: "debug/prelude"
  gem "readapt", "~> 2.0"

  # Code quality and style enforcement with advanced linting
  gem "rubocop-rails-omakase", "~> 1.1", require: false
  gem "rubocop-performance", "~> 1.26", require: false
  gem "rubocop-rspec", "~> 3.0", require: false
  gem "rubocop-thread_safety", "~> 0.5", require: false

  # Security scanning in development with comprehensive coverage
  gem "dawnscanner", "~> 2.2", require: false

  # Performance testing and benchmarking
  gem "benchmark-ips", "~> 2.13"
  gem "stackprof", "~> 0.2"
end

group :development do
  # Enhanced console with advanced features and better introspection
  gem "web-console", "~> 4.2"
  gem "awesome_print", "~> 1.9"
  gem "pry-rails", "~> 0.3"
  gem "pry-byebug", "~> 3.10"
  gem "pry-stack_explorer", "~> 0.6"
end

group :test do
  # Comprehensive testing suite with advanced features
  gem "capybara", "~> 3.40"
  gem "selenium-webdriver", "~> 4.10"
  # gem "webdrivers", "~> 5.3"  # Deprecated - selenium-webdriver handles driver management
  gem "cuprite", "~> 0.15"  # Headless Chrome testing

  # API testing with comprehensive coverage
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.5"
  gem "shoulda-matchers", "~> 6.2"
  gem "webmock", "~> 3.23"
  gem "vcr", "~> 6.2"

  # Performance and load testing
  gem "test-prof", "~> 1.3"
end

# =============================================================================
# PRODUCTION & DEPLOYMENT - Zero-downtime, scalable deployment
# =============================================================================
# Zero-downtime deployment with advanced orchestration
gem "kamal", "~> 2.7", require: false

# Platform-specific optimizations for all deployment targets
gem "tzinfo-data", "~> 1.2024", platforms: %i[ mingw mswin x64_mingw jruby ]

# Active Storage enhancements with advanced image processing
gem "image_processing", "~> 1.14", require: false
gem "ruby-vips", "~> 2.2", require: false

# Rails 8 optimized caching and database connection handling
gem "solid_cable", "~> 3.0"

# =============================================================================
# ENTERPRISE FEATURES - Advanced enterprise capabilities
# =============================================================================
# Feature flags for gradual rollouts with advanced targeting
gem "flipper", "~> 1.3"
gem "flipper-ui", "~> 1.3"
gem "flipper-active_record", "~> 1.3"

# Advanced enums with metadata and validation
gem "enumerize", "~> 2.8"

# Advanced statistical analysis with machine learning capabilities
gem "statsd-instrument", "~> 3.7"
gem "datadog", "~> 2.1"

# Advanced logging and audit trails
gem "lograge", "~> 0.14"
gem "request_store", "~> 1.7"

# Blockchain integration (optional) - Ready for Web3 features
# gem "eth", "~> 0.5"  # Uncommented for production use

# Advanced internationalization with performance optimization
gem "fast_gettext", "~> 2.4"
gem "i18n-js", "~> 4.2"