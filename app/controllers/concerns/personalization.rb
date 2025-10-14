# frozen_string_literal: true

# Personalization Concern - Enterprise-Grade User Tracking and Personalization
#
# This concern provides sophisticated user activity tracking, intelligent caching,
# and personalized content delivery with comprehensive error handling and performance monitoring.
#
# @version 2.0.0
# @author Enterprise Architecture Team
#
module Personalization
  extend ActiveSupport::Concern

  # ============================================================================
  # Configuration Constants
  # ============================================================================

  # Cache configuration
  PERSONALIZATION_CACHE_EXPIRY = 1.hour
  CACHE_VERSION = 'v2.0'
  CACHE_COMPRESSION_THRESHOLD = 1.kilobyte

  # Tracking configuration
  TRACKING_DEBOUNCE_WINDOW = 30.seconds
  MAX_TRACKING_RETRIES = 3
  BACKGROUND_TRACKING_ENABLED = true

  # Performance monitoring
  PERFORMANCE_METRICS_ENABLED = true
  SLOW_QUERY_THRESHOLD = 100.milliseconds

  # Event types
  EVENT_TYPES = {
    page_view: 'Page View',
    product_view: 'Product View',
    category_view: 'Category View',
    personalization_request: 'Personalization Request'
  }.freeze

  # ============================================================================
  # Enhanced Error Classes
  # ============================================================================

  # Base error class for personalization-related exceptions
  class PersonalizationError < StandardError
    attr_reader :user_id, :context

    def initialize(message, user_id: nil, context: {})
      super(message)
      @user_id = user_id
      @context = context
    end
  end

  # Raised when tracking operations fail
  class TrackingError < PersonalizationError; end

  # Raised when personalization service fails
  class PersonalizationServiceError < PersonalizationError; end

  # Raised when caching operations fail
  class CacheError < PersonalizationError; end

  # ============================================================================
  # Rails Integration
  # ============================================================================

  included do
    before_action :track_user_activity_with_error_handling
    helper_method :personalized_content_with_fallback

    # Register custom error handlers
    rescue_from TrackingError, with: :handle_tracking_error
    rescue_from PersonalizationServiceError, with: :handle_personalization_error
    rescue_from CacheError, with: :handle_cache_error
  end

  # ============================================================================
  # Enhanced User Activity Tracking
  # ============================================================================

  private

  # Enhanced activity tracking with comprehensive error handling and performance monitoring
  #
  # @return [void]
  # @raise [TrackingError] if tracking fails after retries
  def track_user_activity_with_error_handling
    return unless user_authenticated?

    track_with_performance_monitoring do
      track_page_view
      track_contextual_views
    end
  rescue StandardError => e
    handle_tracking_failure(e)
  end

  # Track page view with enhanced metadata collection
  #
  # @return [void]
  def track_page_view
    event_properties = build_page_view_properties

    if BACKGROUND_TRACKING_ENABLED
      track_in_background(:page_view, event_properties)
    else
      perform_tracking(:page_view, event_properties)
    end
  end

  # Track product and category views if present
  #
  # @return [void]
  def track_contextual_views
    track_product_view if @product.present? && @product.persisted?
    track_category_view if @category.present? && @category.persisted?
  end

  # Track product view with validation and error handling
  #
  # @return [void]
  def track_product_view
    validate_tracking_context(:product)

    if BACKGROUND_TRACKING_ENABLED
      track_product_in_background
    else
      perform_product_tracking
    end
  end

  # Track category view with validation and error handling
  #
  # @return [void]
  def track_category_view
    validate_tracking_context(:category)

    if BACKGROUND_TRACKING_ENABLED
      track_category_in_background
    else
      perform_category_tracking
    end
  end

  # ============================================================================
  # Background Job Processing
  # ============================================================================

  # Queue page view tracking job
  #
  # @param event_properties [Hash] event data to track
  # @return [void]
  def track_in_background(event_type, event_properties)
    UserActivityTrackingJob.perform_later(
      user_id: current_user.id,
      event_type: event_type,
      properties: event_properties,
      timestamp: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("Failed to queue #{event_type} tracking job: #{e.message}")
    # Fallback to synchronous tracking
    perform_tracking(event_type, event_properties)
  end

  # Queue product view tracking job
  #
  # @return [void]
  def track_product_in_background
    UserActivityTrackingJob.perform_later(
      user_id: current_user.id,
      event_type: :product_view,
      properties: build_product_view_properties,
      timestamp: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("Failed to queue product view tracking job: #{e.message}")
    perform_product_tracking
  end

  # Queue category view tracking job
  #
  # @return [void]
  def track_category_in_background
    UserActivityTrackingJob.perform_later(
      user_id: current_user.id,
      event_type: :category_view,
      properties: build_category_view_properties,
      timestamp: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("Failed to queue category view tracking job: #{e.message}")
    perform_category_tracking
  end

  # ============================================================================
  # Synchronous Tracking Operations
  # ============================================================================

  # Perform synchronous tracking with retry logic
  #
  # @param event_type [Symbol] type of event to track
  # @param properties [Hash] event properties
  # @return [void]
  def perform_tracking(event_type, properties)
    retry_count = 0

    begin
      case event_type
      when :page_view
        perform_ahoy_tracking(EVENT_TYPES[:page_view], properties)
      when :product_view
        perform_product_tracking_sync(properties)
      when :category_view
        perform_category_tracking_sync(properties)
      end
    rescue StandardError => e
      retry_count += 1
      if retry_count < MAX_TRACKING_RETRIES
        Rails.logger.warn("Tracking retry #{retry_count}/#{MAX_TRACKING_RETRIES} for #{event_type}: #{e.message}")
        retry
      else
        raise TrackingError.new(
          "Failed to track #{event_type} after #{MAX_TRACKING_RETRIES} retries",
          user_id: current_user&.id,
          context: { event_type: event_type, properties: properties }
        )
      end
    end
  end

  # Perform synchronous product tracking
  #
  # @return [void]
  def perform_product_tracking
    perform_tracking(:product_view, build_product_view_properties)
  end

  # Perform synchronous category tracking
  #
  # @return [void]
  def perform_category_tracking
    perform_tracking(:category_view, build_category_view_properties)
  end

  # Perform synchronous product tracking with database operation
  #
  # @param properties [Hash] tracking properties
  # @return [void]
  def perform_product_tracking_sync(properties)
    ProductView.create_or_update!(
      user: current_user,
      product: @product,
      viewed_at: properties[:viewed_at],
      metadata: properties[:metadata]
    )
  end

  # Perform synchronous category tracking with database operation
  #
  # @param properties [Hash] tracking properties
  # @return [void]
  def perform_category_tracking_sync(properties)
    CategoryView.create_or_update!(
      user: current_user,
      category: @category,
      viewed_at: properties[:viewed_at],
      metadata: properties[:metadata]
    )
  end

  # ============================================================================
  # Enhanced Personalization Content
  # ============================================================================

  # Enhanced personalized content with sophisticated caching and error handling
  #
  # @return [Hash] personalized content data or empty hash on failure
  def personalized_content_with_fallback
    return {} unless user_authenticated?

    fetch_personalized_content_with_rescue
  rescue StandardError => e
    handle_personalization_error(e)
    {}
  end

  # Fetch personalized content with comprehensive error handling
  #
  # @return [Hash] personalized content data
  # @raise [PersonalizationServiceError] if service fails completely
  def fetch_personalized_content_with_rescue
    cache_key = build_personalization_cache_key

    Rails.cache.fetch(cache_key, expires_in: PERSONALIZATION_CACHE_EXPIRY, compress: true) do
      fetch_personalized_content_from_service
    end
  rescue StandardError => e
    raise CacheError.new(
      "Failed to fetch personalized content from cache",
      user_id: current_user&.id,
      context: { cache_key: cache_key }
    )
  end

  # Fetch content from personalization service with monitoring
  #
  # @return [Hash] service response data
  def fetch_personalized_content_from_service
    service = PersonalizationService.new(current_user)

    track_personalization_request

    service.personalized_recommendations
  rescue StandardError => e
    raise PersonalizationServiceError.new(
      "Personalization service failed",
      user_id: current_user&.id,
      context: { service_class: 'PersonalizationService' }
    )
  end

  # ============================================================================
  # Property Builders
  # ============================================================================

  # Build comprehensive page view properties
  #
  # @return [Hash] page view event properties
  def build_page_view_properties
    {
      controller: controller_name,
      action: action_name,
      params: filtered_params,
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      referrer: request.referrer,
      timestamp: Time.current,
      session_id: session.id,
      request_id: request.request_id
    }
  end

  # Build product view properties with enhanced metadata
  #
  # @return [Hash] product view event properties
  def build_product_view_properties
    {
      product_id: @product.id,
      product_slug: @product.slug,
      product_category_ids: @product.category_ids,
      viewed_at: Time.current,
      metadata: {
        price: @product.price,
        availability: @product.available?,
        rating: @product.average_rating,
        view_context: extract_view_context
      }
    }
  end

  # Build category view properties with enhanced metadata
  #
  # @return [Hash] category view event properties
  def build_category_view_properties
    {
      category_id: @category.id,
      category_slug: @category.slug,
      category_parent_id: @category.parent_id,
      viewed_at: Time.current,
      metadata: {
        product_count: @category.products.count,
        subcategory_count: @category.children.count,
        view_context: extract_view_context
      }
    }
  end

  # ============================================================================
  # Cache Key Management
  # ============================================================================

  # Build sophisticated cache key with versioning and context
  #
  # @return [String] cache key string
  def build_personalization_cache_key
    user_context = current_user.cache_key_with_version
    locale = I18n.locale.to_s
    device_type = extract_device_type

    [
      'personalization',
      CACHE_VERSION,
      user_context,
      locale,
      device_type,
      Digest::MD5.hexdigest(request.user_agent.to_s)[0..8]
    ].join(':')
  end

  # ============================================================================
  # Validation and Context Extraction
  # ============================================================================

  # Validate tracking context before operations
  #
  # @param context_type [Symbol] type of context to validate
  # @return [void]
  # @raise [ArgumentError] if context is invalid
  def validate_tracking_context(context_type)
    case context_type
    when :product
      unless @product&.persisted? && current_user&.persisted?
        raise ArgumentError, "Invalid product tracking context: product or user not persisted"
      end
    when :category
      unless @category&.persisted? && current_user&.persisted?
        raise ArgumentError, "Invalid category tracking context: category or user not persisted"
      end
    end
  end

  # Extract view context for enhanced tracking
  #
  # @return [Hash] view context metadata
  def extract_view_context
    {
      controller: controller_name,
      action: action_name,
      format: request.format.symbol,
      xhr: request.xhr?,
      mobile: browser.mobile?,
      bot: browser.bot?
    }
  end

  # Extract device type for cache segmentation
  #
  # @return [Symbol] device type
  def extract_device_type
    return :mobile if browser.mobile?
    return :tablet if browser.tablet?
    :desktop
  end

  # ============================================================================
  # Enhanced Parameter Filtering
  # ============================================================================

  # Enhanced parameter filtering with security considerations
  #
  # @return [Hash] filtered parameters safe for tracking
  def filtered_params
    # Define sensitive parameters that should never be tracked
    sensitive_params = %i[
      password password_confirmation
      credit_card_number cvv
      ssn social_security_number
      api_key secret_token
      authenticity_token
    ]

    # Define parameters to exclude from tracking for privacy
    excluded_params = %i[
      controller action utf8 authenticity_token
      _method _csrf_token
    ]

    # Merge and filter parameters
    all_excluded = (sensitive_params + excluded_params).uniq

    # Sanitize parameter values for security
    sanitized = params.except(*all_excluded).to_unsafe_h

    # Truncate long parameter values to prevent cache bloat
    sanitized.transform_values do |value|
      case value
      when String
        value.length > 255 ? "#{value[0..252]}..." : value
      when Array
        value.take(10) # Limit array size for tracking
      else
        value
      end
    end
  end

  # ============================================================================
  # Performance Monitoring
  # ============================================================================

  # Monitor performance of operations with timing and metrics
  #
  # @param operation_name [String] name of operation being monitored
  # @yield block to monitor
  # @return [Object] result of the block
  def track_with_performance_monitoring(operation_name = 'unknown')
    return yield unless PERFORMANCE_METRICS_ENABLED

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    begin
      result = yield

      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      duration = (end_time - start_time) * 1000 # Convert to milliseconds

      record_performance_metric(operation_name, duration)

      result
    rescue StandardError => e
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      duration = (end_time - start_time) * 1000

      record_performance_metric("#{operation_name}_error", duration)

      raise e
    end
  end

  # Record performance metrics for monitoring
  #
  # @param operation [String] operation name
  # @param duration_ms [Float] duration in milliseconds
  # @return [void]
  def record_performance_metric(operation, duration_ms)
    if duration_ms > SLOW_QUERY_THRESHOLD
      Rails.logger.warn(
        "Slow personalization operation detected",
        operation: operation,
        duration_ms: duration_ms,
        threshold_ms: SLOW_QUERY_THRESHOLD,
        user_id: current_user&.id
      )
    end

    # Here you could integrate with monitoring services like DataDog, NewRelic, etc.
    # Example: DataDog.statsd.increment('personalization.operation', tags: ["operation:#{operation}"])
  end

  # ============================================================================
  # Error Handling and Fallbacks
  # ============================================================================

  # Handle tracking errors gracefully
  #
  # @param error [StandardError] the error that occurred
  # @return [void]
  def handle_tracking_error(error)
    Rails.logger.error(
      "Personalization tracking error",
      error: error.message,
      user_id: error.user_id,
      context: error.context,
      backtrace: error.backtrace[0..5]
    )

    # Could implement circuit breaker pattern here
    # Example: increment failure count and disable tracking if threshold exceeded
  end

  # Handle personalization service errors
  #
  # @param error [StandardError] the error that occurred
  # @return [void]
  def handle_personalization_error(error)
    Rails.logger.error(
      "Personalization service error",
      error: error.message,
      user_id: error.user_id,
      context: error.context,
      backtrace: error.backtrace[0..5]
    )

    # Return cached fallback content if available
    return_fallback_content
  end

  # Handle cache errors
  #
  # @param error [StandardError] the error that occurred
  # @return [void]
  def handle_cache_error(error)
    Rails.logger.error(
      "Personalization cache error",
      error: error.message,
      user_id: error.user_id,
      context: error.context,
      backtrace: error.backtrace[0..5]
    )

    # Attempt to fetch fresh content without caching
    fetch_personalized_content_from_service
  rescue StandardError => fallback_error
    Rails.logger.error("Fallback content fetch also failed", error: fallback_error.message)
    {}
  end

  # ============================================================================
  # Utility Methods
  # ============================================================================

  # Check if user is authenticated with enhanced validation
  #
  # @return [Boolean] true if user is authenticated and valid
  def user_authenticated?
    user_signed_in? && current_user&.persisted? && !current_user&.blocked?
  end

  # Track personalization request for analytics
  #
  # @return [void]
  def track_personalization_request
    return unless PERFORMANCE_METRICS_ENABLED

    # Track personalization request event
    perform_ahoy_tracking(EVENT_TYPES[:personalization_request], {
      user_id: current_user.id,
      timestamp: Time.current,
      cache_hit: false # Will be updated when cache is checked
    })
  end

  # Perform Ahoy tracking with error handling
  #
  # @param event_name [String] name of the event
  # @param properties [Hash] event properties
  # @return [void]
  def perform_ahoy_tracking(event_name, properties)
    Ahoy.track(event_name, properties)
  rescue StandardError => e
    Rails.logger.error("Ahoy tracking failed", event: event_name, error: e.message)
    # Continue execution - tracking failure shouldn't break the request
  end

  # Return fallback content when personalization fails
  #
  # @return [Hash] fallback content structure
  def return_fallback_content
    {
      recommendations: [],
      fallback: true,
      reason: 'service_unavailable',
      timestamp: Time.current
    }
  end

  # ============================================================================
  # Backward Compatibility
  # ============================================================================

  # Maintain backward compatibility with original method names
  alias_method :track_user_activity, :track_user_activity_with_error_handling
  alias_method :personalized_content, :personalized_content_with_fallback
end