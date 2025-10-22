# frozen_string_literal: true

# Domain event representing failure of image processing
# Indicates that processing could not be completed successfully
class ImageProcessingFailedEvent < CameraCaptureEvent
  attr_reader :error_message, :error_code, :failure_timestamp, :retry_recommended, :error_details

  # Error categories for classification
  ERROR_CATEGORIES = {
    TEMPORARY_FAILURE: 'temporary_failure',
    PERMANENT_FAILURE: 'permanent_failure',
    RESOURCE_EXHAUSTED: 'resource_exhausted',
    NETWORK_ERROR: 'network_error',
    VALIDATION_ERROR: 'validation_error',
    SECURITY_ERROR: 'security_error',
    PROCESSING_TIMEOUT: 'processing_timeout'
  }.freeze

  # Create new image processing failed event
  # @param aggregate_id [String] camera capture aggregate ID
  # @param error_message [String] human-readable error description
  # @param error_code [String] error code for programmatic handling
  # @param failure_timestamp [Time] when the failure occurred
  # @param retry_recommended [Boolean] whether retry is recommended
  # @param error_details [Hash] additional error context
  # @param metadata [Hash] additional event metadata
  def initialize(
    aggregate_id,
    error_message:,
    error_code:,
    failure_timestamp:,
    retry_recommended:,
    error_details: {},
    **metadata
  )
    super(aggregate_id, metadata: metadata)

    @error_message = error_message
    @error_code = error_code
    @failure_timestamp = failure_timestamp
    @retry_recommended = retry_recommended
    @error_details = error_details.freeze

    validate_event_data!
  end

  # Get event data for serialization
  # @return [Hash] serializable event data
  def event_data
    super.merge(
      error_message: @error_message,
      error_code: @error_code,
      failure_timestamp: @failure_timestamp,
      retry_recommended: @retry_recommended,
      error_details: @error_details
    )
  end

  # Get error category for classification
  # @return [Symbol] error category
  def error_category
    ERROR_CATEGORIES[@error_code.to_sym] || :unknown
  end

  # Check if error is temporary and can be retried
  # @return [Boolean] true if retryable
  def retryable?
    @retry_recommended && temporary_error?
  end

  # Check if error is permanent
  # @return [Boolean] true if permanent
  def permanent_error?
    !temporary_error?
  end

  # Check if error is due to temporary conditions
  # @return [Boolean] true if temporary
  def temporary_error?
    [:TEMPORARY_FAILURE, :NETWORK_ERROR, :RESOURCE_EXHAUSTED].include?(error_category)
  end

  # Get recommended retry delay in seconds
  # @return [Integer] delay in seconds
  def recommended_retry_delay
    case error_category
    when :NETWORK_ERROR
      30 # 30 seconds for network issues
    when :RESOURCE_EXHAUSTED
      60 # 1 minute for resource issues
    when :TEMPORARY_FAILURE
      15 # 15 seconds for temporary failures
    else
      0 # No retry for permanent errors
    end
  end

  # Get error severity level
  # @return [Symbol] severity level
  def severity_level
    case error_category
    when :SECURITY_ERROR
      :critical
    when :PERMANENT_FAILURE
      :high
    when :VALIDATION_ERROR
      :medium
    when :PROCESSING_TIMEOUT
      :medium
    when :TEMPORARY_FAILURE, :NETWORK_ERROR, :RESOURCE_EXHAUSTED
      :low
    else
      :medium
    end
  end

  # Get user-friendly error message
  # @return [String] user-friendly message
  def user_friendly_message
    case error_category
    when :NETWORK_ERROR
      'Network connection issue. Please check your connection and try again.'
    when :RESOURCE_EXHAUSTED
      'Server is busy. Please wait a moment and try again.'
    when :VALIDATION_ERROR
      'Image quality or format issue. Please capture a clearer image.'
    when :SECURITY_ERROR
      'Security validation failed. Please contact support if this persists.'
    when :PROCESSING_TIMEOUT
      'Processing took too long. Please try with a smaller or simpler image.'
    else
      'Processing failed. Please try again or contact support.'
    end
  end

  # Get technical error details for logging
  # @return [Hash] technical error information
  def technical_details
    {
      error_code: @error_code,
      category: error_category,
      severity: severity_level,
      retryable: retryable?,
      retry_delay: recommended_retry_delay,
      timestamp: @failure_timestamp,
      additional_context: @error_details
    }
  end

  # Check if this error should trigger alerting
  # @return [Boolean] true if should alert
  def should_alert?
    [:critical, :high].include?(severity_level) || error_category == :SECURITY_ERROR
  end

  # Get monitoring tags for this error
  # @return [Array<String>] monitoring tags
  def monitoring_tags
    tags = []
    tags << "error_category:#{error_category}"
    tags << "severity:#{severity_level}"
    tags << "retryable:#{retryable?}"

    if @error_details[:component]
      tags << "component:#{@error_details[:component]}"
    end

    tags
  end

  private

  # Validate event-specific data
  def validate_event_data!
    raise ArgumentError, 'Error message is required' if @error_message.blank?
    raise ArgumentError, 'Error code is required' if @error_code.blank?
    raise ArgumentError, 'Failure timestamp is required' unless @failure_timestamp
  end
end