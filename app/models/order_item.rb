# frozen_string_literal: true

# OrderItem model refactored for architectural purity, performance, and scalability.
# Business logic is decoupled into services for clarity and testability.
# Optimized for asymptotic performance and resilience with error handling.
class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :item

  # Enhanced validations with custom error messages for better UX and resilience.
  validates :quantity, presence: true, numericality: { greater_than: 0, only_integer: true, message: "must be a positive integer" }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0, message: "must be non-negative" }

  # Use service for setting unit price to avoid N+1 queries and add resilience.
  before_validation :set_unit_price_from_service, on: :create

  # Event-driven pattern: Publish events after creation for state integrity and auditability.
  after_commit :publish_creation_event, on: :create

  # Scope for preloading associations to optimize queries and prevent N+1.
  scope :with_associations, -> { includes(:item, :order) }

  # Performance: Cache subtotal calculation if frequently accessed.
  # @return [BigDecimal] The cached subtotal.
  def cached_subtotal
    Rails.cache.fetch("order_item_subtotal_#{id}", expires_in: 1.hour) do
      subtotal
    end
  end

  # Calculate subtotal using dedicated service for precision and decoupling.
  # @return [BigDecimal] The subtotal amount.
  def subtotal
    SubtotalCalculator.calculate(unit_price, quantity)
  end

  private

  # Sets unit price using the UnitPriceSetter service with error handling.
  def set_unit_price_from_service
    self.unit_price = UnitPriceSetter.set_unit_price(self)
  rescue StandardError => e
    # Log error and add validation error for resilience.
    Rails.logger.error("Unit price setting failed for OrderItem #{id}: #{e.message}")
    errors.add(:unit_price, "could not be set due to an error")
  end

  # Publishes an event after creation for auditability and CQRS compatibility.
  def publish_creation_event
    # In a full event-sourcing system, enqueue an event like OrderItemCreatedEvent.
    # For now, log and optionally enqueue a background job.
    Rails.logger.info("OrderItem created: ID=#{id}, Order=#{order_id}, Item=#{item_id}, Quantity=#{quantity}")
    # Example: EventPublisher.publish('order_item.created', self.attributes)
  end
end
