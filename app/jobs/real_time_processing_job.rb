# frozen_string_literal: true

# Background job for real-time analytics processing
# Extracted to improve performance and scalability
# Uses Sidekiq for asynchronous processing with retry logic
class RealTimeProcessingJob
  include Sidekiq::Worker
  include AnalyticsMetricConfiguration

  sidekiq_options retry: max_retry_attempts, backtrace: true, queue: :analytics

  # Perform real-time processing for a metric
  def perform(metric_id)
    metric = AnalyticsMetric.find_by(id: metric_id)
    return unless metric

    service = AnalyticsMetricService.new

    # Process with circuit breaker for resilience
    with_circuit_breaker do
      service.process_real_time_analytics(metric)
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("Metric #{metric_id} not found for real-time processing")
  rescue StandardError => e
    handle_job_error(e, metric_id)
  end

  private

  def with_circuit_breaker
    circuit_breaker = CircuitBreaker.new(name: 'real_time_processing')
    circuit_breaker.call { yield }
  rescue CircuitBreaker::OpenError
    Rails.logger.warn('Circuit breaker open for real-time processing')
  end

  def handle_job_error(error, metric_id)
    Rails.logger.error("Real-time processing failed for metric #{metric_id}: #{error.message}")

    # Retry with exponential backoff
    retry_job(metric_id) if should_retry?(error)
  end

  def should_retry?(error)
    # Retry on transient errors
    error.is_a?(ActiveRecord::StatementTimeout) || error.is_a?(Net::Timeout)
  end

  def retry_job(metric_id)
    self.class.perform_in(retry_backoff_base * (attempts + 1), metric_id)
  end
end