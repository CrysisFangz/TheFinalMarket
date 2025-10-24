# app/services/event_publisher.rb
class EventPublisher
  def self.publish(event_type, data = {})
    # In a real system, this would publish to a message queue like Sidekiq or Kafka
    # For now, just log it
    Rails.logger.info("Event published: #{event_type} - #{data.inspect}")
  end
end