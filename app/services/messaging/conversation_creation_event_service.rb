# frozen_string_literal: true

# =============================================================================
# ConversationCreationEventService - Service for Handling Conversation Creation Events
# =============================================================================
# Decouples business logic for conversation creation events, ensuring separation of concerns.
# Implements CQRS command handling with resilient error management and performance optimization.
#
# Architecture: Service Object + Event Sourcing + Circuit Breaker
# Performance: O(1) event processing with async projections
# Scalability: Distributed event handling with idempotent operations
# Resilience: Adaptive retry mechanisms and dead letter queue integration
# =============================================================================

class ConversationCreationEventService
  include Concerns::CircuitBreaker
  include Concerns::Telemetry
  include Concerns::Caching

  # ==================== DEPENDENCY INJECTION ====================
  attr_accessor :conversation_repository, :event_store, :cache_store, :notification_service

  # ==================== CONSTANTS ====================
  MAX_RETRY_ATTEMPTS = 3
  RETRY_DELAY = 1.second
  PROJECTION_TIMEOUT = 5.seconds

  # ==================== EVENT HANDLING ====================

  # Process a conversation creation event
  def process_event(event)
    with_circuit_breaker("process_conversation_creation_event") do
      validate_event!(event)
      start_time = Time.current

      # Idempotent processing
      return if event_already_processed?(event)

      result = nil
      transaction do
        result = execute_event_processing(event)
        mark_event_as_processed(event)
      end

      # Trigger projections and notifications
      trigger_projections(event)
      broadcast_notifications(event)

      record_operation_duration("process_event", start_time)
      increment_counter("events_processed")

      ServiceResult.success(result, "Event processed successfully")
    end
  end

  # Rebuild conversation state from events
  def rebuild_conversation_state(conversation_id)
    with_circuit_breaker("rebuild_conversation_state") do
      start_time = Time.current

      events = ConversationCreationEvent.for_conversation(conversation_id).ordered
      conversation = Conversation.new

      events.each do |event|
        event.apply_to(conversation)
      end

      # Update projection
      update_conversation_projection(conversation)

      record_operation_duration("rebuild_state", start_time)
      increment_counter("states_rebuilt")

      conversation
    end
  end

  # ==================== PROJECTIONS ====================

  # Update read model projections
  def update_conversation_projection(conversation)
    ConversationReadModel.find_or_create_by(conversation_id: conversation.id).tap do |projection|
      projection.update!(
        sender_id: conversation.sender_id,
        recipient_id: conversation.recipient_id,
        conversation_type: conversation.conversation_type,
        participant_count: conversation.participants.size,
        created_at: conversation.created_at,
        last_activity_at: conversation.updated_at,
        status: conversation.archived? ? 'archived' : 'active'
      )
    end
  rescue StandardError => e
    Rails.logger.error("Failed to update conversation projection: #{e.message}")
    # Implement retry or dead letter queue
  end

  # ==================== NOTIFICATIONS ====================

  # Broadcast real-time notifications
  def broadcast_notifications(event)
    notification_service.broadcast_to_conversation(event.entity_id, {
      type: 'conversation_created',
      conversation_id: event.entity_id,
      creator_id: event.creator_id,
      participants: event.data[:participants],
      timestamp: event.created_at
    })
  rescue StandardError => e
    Rails.logger.error("Failed to broadcast notifications for event #{event.id}: #{e.message}")
  end

  # ==================== VALIDATION ====================

  def validate_event!(event)
    unless event.is_a?(ConversationCreationEvent)
      raise ValidationError, "Invalid event type"
    end

    unless event.data[:participants].present? && event.data[:participants].size >= 2
      raise ValidationError, "Invalid participants"
    end

    unless event.creator_id.present?
      raise ValidationError, "Missing creator"
    end
  end

  # ==================== CACHING ====================

  # Check if event has already been processed
  def event_already_processed?(event)
    cache_key = "processed_event:#{event.id}"
    cache_store.get(cache_key).present?
  end

  # Mark event as processed
  def mark_event_as_processed(event)
    cache_key = "processed_event:#{event.id}"
    cache_store.set(cache_key, true, ttl: 1.day)
  end

  # ==================== ERROR HANDLING ====================

  # Handle processing failures with retry
  def handle_processing_failure(event, error)
    retry_count = event.metadata[:retry_count] || 0

    if retry_count < MAX_RETRY_ATTEMPTS
      # Schedule retry
      ConversationCreationEventRetryJob.perform_in(
        RETRY_DELAY * (2 ** retry_count),
        event.id,
        retry_count + 1
      )
    else
      # Move to dead letter queue
      move_to_dead_letter_queue(event, error)
    end
  end

  # Move failed event to dead letter queue
  def move_to_dead_letter_queue(event, error)
    DeadLetterEvent.create!(
      original_event_id: event.id,
      event_type: event.event_type,
      error_message: error.message,
      error_backtrace: error.backtrace,
      retry_count: event.metadata[:retry_count] || 0
    )

    Rails.logger.error("Event #{event.id} moved to dead letter queue after #{MAX_RETRY_ATTEMPTS} retries")
  end

  # ==================== PRIVATE METHODS ====================

  private

  def execute_event_processing(event)
    # Create or update conversation aggregate
    conversation = Conversation.find_or_initialize_by(id: event.entity_id)
    event.apply_to(conversation)
    conversation.save!
    conversation
  end

  def trigger_projections(event)
    # Async projection update with batching for efficiency
    if event.metadata[:batch_processing]
      ConversationProjectionJob.perform_batch(event.metadata[:batch_event_ids])
    else
      ConversationProjectionJob.perform_later(event.id)
    end
  end

  def transaction(&block)
    ActiveRecord::Base.transaction(&block)
  end

  # ==================== DEPENDENCY CONFIGURATION ====================
  def configure_dependencies
    self.conversation_repository = ConversationRepository::Optimized.instance
    self.event_store = EventStore::Persistent.instance
    self.cache_store = CacheStore::RedisBacked.instance
    self.notification_service = NotificationService::RealTime.instance
  end

  # Auto-configure
  configure_dependencies
end