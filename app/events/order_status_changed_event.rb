# app/events/order_status_changed_event.rb
class OrderStatusChangedEvent
  attr_reader :order, :old_status, :new_status

  def initialize(order, old_status, new_status)
    @order = order
    @old_status = old_status
    @new_status = new_status
  end

  def publish
    # Publish to event bus or queue
    EventPublisher.publish(self)
  end
end