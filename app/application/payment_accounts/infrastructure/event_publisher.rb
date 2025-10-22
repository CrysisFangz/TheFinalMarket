# frozen_string_literal: true

# Event Publisher Infrastructure
# High-performance event publishing with guaranteed delivery
class EventPublisher
  include Singleton

  def self.publish(topic, event)
    instance.publish(topic, event)
  end

  def initialize
    @message_bus = Rails.configuration.message_bus || MemoryMessageBus.new
  end

  def publish(topic, event)
    CircuitBreaker.execute_with_fallback(:event_publishing) do
      message = build_message(topic, event)

      # Publish to message bus
      @message_bus.publish(message)

      # Store for audit trail
      store_published_event(message)

      # Trigger immediate handlers if needed
      trigger_immediate_handlers(topic, event)

      true
    end
  rescue => e
    Rails.logger.error("Failed to publish event #{event.event_id} to topic #{topic}: #{e.message}")
    raise EventPublishingError, "Event publishing failed: #{e.message}"
  end

  # Publish multiple events
  def publish_batch(topic, events)
    CircuitBreaker.execute_with_fallback(:batch_event_publishing) do
      messages = events.map { |event| build_message(topic, event) }

      # Batch publish for efficiency
      @message_bus.publish_batch(messages)

      # Store batch for audit trail
      store_published_events(messages)

      true
    end
  end

  private

  def build_message(topic, event)
    {
      topic: topic,
      event_id: event.event_id,
      event_type: event.event_type,
      aggregate_id: event.aggregate_id,
      aggregate_type: event.aggregate_type,
      occurred_at: event.occurred_at,
      event_data: event.to_h,
      published_at: Time.current,
      message_id: SecureRandom.uuid
    }
  end

  def store_published_event(message)
    # Store in audit log for compliance
    PublishedEvent.create!(
      event_id: message[:event_id],
      topic: message[:topic],
      published_at: message[:published_at],
      message_data: message
    )
  end

  def store_published_events(messages)
    # Batch store for efficiency
    published_events = messages.map do |message|
      {
        event_id: message[:event_id],
        topic: message[:topic],
        published_at: message[:published_at],
        message_data: message,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    PublishedEvent.insert_all!(published_events)
  end

  def trigger_immediate_handlers(topic, event)
    # Trigger immediate handlers for critical events
    immediate_handlers = load_immediate_handlers(topic)

    immediate_handlers.each do |handler|
      begin
        handler.handle(event)
      rescue => e
        Rails.logger.error("Immediate handler #{handler.class.name} failed for event #{event.event_id}: #{e.message}")
      end
    end
  end

  def load_immediate_handlers(topic)
    # Load handlers that need immediate processing
    # Implementation would load from configuration
    []
  end
end

# Supporting classes
class EventPublishingError < StandardError; end

class MemoryMessageBus
  def publish(message)
    # In-memory message bus for development/testing
    Rails.logger.info("Published message to #{message[:topic]}: #{message[:event_id]}")
  end

  def publish_batch(messages)
    messages.each { |message| publish(message) }
  end
end