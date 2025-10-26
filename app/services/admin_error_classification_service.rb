# 🚀 ENTERPRISE-GRADE ERROR CLASSIFICATION SERVICE
# Advanced Error Taxonomy | Adaptive Recovery | Hyperscale Resilience
class AdminErrorClassificationService
  def initialize(error)
    @error = error
    @error_type = error.class.name
    @error_message = error.message
  end

  def classify
    OpenStruct.new(
      type: determine_error_type,
      severity: determine_severity,
      category: determine_category,
      http_status: determine_http_status,
      retryable: determine_retryability,
      recovery_strategy: determine_recovery_strategy
    )
  end

  private

  def determine_error_type
    case @error_type
    when /AuthenticationError/ then :authentication
    when /AuthorizationError/ then :authorization
    when /ActiveRecord::RecordNotFound/ then :not_found
    when /ActiveRecord::RecordInvalid/ then :validation
    when /Timeout::Error/ then :timeout
    when /CircuitBreaker::Open/ then :circuit_breaker
    when /Redis::CannotConnectError/ then :cache_failure
    when /StandardError/ then :generic
    else :unknown
    end
  end

  def determine_severity
    case determine_error_type
    when :authentication, :authorization then :critical
    when :not_found, :validation then :moderate
    when :timeout, :circuit_breaker, :cache_failure then :high
    else :low
    end
  end

  def determine_category
    case determine_error_type
    when :authentication, :authorization then :security
    when :not_found, :validation then :data
    when :timeout, :circuit_breaker, :cache_failure then :infrastructure
    else :application
    end
  end

  def determine_http_status
    case determine_error_type
    when :authentication then 401
    when :authorization then 403
    when :not_found then 404
    when :validation then 422
    when :timeout, :circuit_breaker then 503
    when :cache_failure then 503
    else 500
    end
  end

  def determine_retryability
    case determine_error_type
    when :timeout, :circuit_breaker, :cache_failure then true
    when :validation, :not_found then false
    else false
    end
  end

  def determine_recovery_strategy
    case determine_error_type
    when :timeout then :exponential_backoff
    when :circuit_breaker then :circuit_recovery
    when :cache_failure then :cache_reconnect
    when :validation then :user_input_correction
    else :graceful_degradation
    end
  end
end