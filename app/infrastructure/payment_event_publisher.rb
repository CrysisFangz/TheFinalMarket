# Payment Event Publisher
# Publishes events to event store and message bus
# for event sourcing and decoupled communication.

class PaymentEventPublisher
  def initialize
    @event_store = EventStore.new
    @message_bus = MessageBus.new
  end

  def publish(event)
    @event_store.append(event)
    @message_bus.publish(event)
  end

  def publish_circuit_open_event(error)
    event = CircuitOpenEvent.new(error: error)
    publish(event)
  end
end