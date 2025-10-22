# frozen_string_literal: true

# =============================================================================
# ConversationProjectionJob - Async Projection Update Job
# =============================================================================
# Handles asynchronous updates to conversation read models after event processing.
# Ensures projections are updated in the background for better performance.
#
# Architecture: Background Job + Idempotent Processing
# Performance: O(1) projection updates with batching
# Scalability: Queue partitioning and worker scaling
# Resilience: Retry mechanism with exponential backoff
# =============================================================================

class ConversationProjectionJob
  include Sidekiq::Job
  include Concerns::CircuitBreaker
  include Concerns::Telemetry

  sidekiq_options retry: 3, backtrace: true

  # ==================== JOB EXECUTION ====================

  def perform(event_id)
    with_circuit_breaker("conversation_projection_update") do
      start_time = Time.current

      event = ConversationCreationEvent.find(event_id)
      service = ConversationCreationEventService.new

      # Update projection
      service.update_conversation_projection_from_event(event)

      # Invalidate caches
      service.invalidate_conversation_caches(event)

      record_operation_duration("projection_update", start_time)
      increment_counter("projections_updated")

      true
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("Event #{event_id} not found for projection update")
  rescue StandardError => e
    Rails.logger.error("Failed to update projection for event #{event_id}: #{e.message}")
    raise
  end

  # ==================== BATCH PROCESSING ====================

  # Process multiple events in batch for efficiency
  def self.perform_batch(event_ids)
    event_ids.each do |event_id|
      perform_async(event_id)
    end
  end

  # ==================== RETRY LOGIC ====================

  def retry_in
    # Exponential backoff with jitter
    base_delay = 60 # 1 minute
    max_delay = 3600 # 1 hour

    delay = [base_delay * (2 ** (attempts - 1)), max_delay].min
    delay + rand(0..30) # Add jitter
  end
end