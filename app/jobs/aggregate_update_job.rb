# frozen_string_literal: true

# Background job for updating aggregate metrics
# Extracted to improve performance and scalability
# Uses Sidekiq for asynchronous processing with retry logic
class AggregateUpdateJob
  include Sidekiq::Worker
  include AnalyticsMetricConfiguration

  sidekiq_options retry: max_retry_attempts, backtrace: true, queue: :analytics

  # Perform aggregate update for a metric
  def perform(metric_id)
    metric = AnalyticsMetric.find_by(id: metric_id)
    return unless metric

    service = AnalyticsMetricService.new

    # Update aggregates with circuit breaker
    with_circuit_breaker do
      service.update_real_time_aggregations(metric)
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("Metric #{metric_id} not found for aggregate update")
  rescue StandardError => e
    handle_job_error(e, metric_id)
  end

  private

  def with_circuit_breaker
    circuit_breaker = CircuitBreaker.new(name: 'aggregate_update')
    circuit_breaker.call { yield }
  rescue CircuitBreaker::OpenError
    Rails.logger.warn('Circuit breaker open for aggregate update')
  end

  def handle_job_error(error, metric_id)
    Rails.logger.error("Aggregate update failed for metric #{metric_id}: #{error.message}")

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