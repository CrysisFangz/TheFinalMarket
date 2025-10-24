# frozen_string_literal: true

class InventoryReservationService
  def initialize(inventory)
    @inventory = inventory
  end

  def reserve(amount, order_id: nil, expires_at: nil, correlation_id: nil)
    return false if amount <= 0

    circuit_breaker = CircuitBreakers::InventoryReservationCircuitBreaker.new
    operation_id = generate_operation_id(correlation_id)

    begin
      circuit_breaker.execute do
        domain_entity = @inventory.load_or_create_domain_entity

        fulfillment_assessment = domain_entity.can_fulfill?(amount)
        unless fulfillment_assessment[:can_fulfill]
          @inventory.record_failed_operation(:reservation, amount, fulfillment_assessment[:reason])
          return false
        end

        max_retries = 3
        retry_count = 0

        begin
          reservation_success = domain_entity.reserve_inventory(
            amount,
            order_id: order_id,
            expires_at: expires_at || 24.hours.from_now
          )

          if reservation_success
            @inventory.apply_domain_events(domain_entity.uncommitted_events)
            @inventory.record_successful_operation(:reservation, amount, operation_id)
            @inventory.broadcast_inventory_update
            return true
          else
            @inventory.record_failed_operation(:reservation, amount, :domain_rejection)
            return false
          end

        rescue ActiveRecord::StaleObjectError
          retry_count += 1
          if retry_count < max_retries
            @inventory.reload
            retry
          else
            @inventory.record_failed_operation(:reservation, amount, :concurrency_conflict)
            return false
          end
        end
      end
    rescue CircuitBreakers::OpenError => e
      @inventory.record_circuit_breaker_failure(:reservation, amount, e)
      return false
    end
  end

  private

  def generate_operation_id(correlation_id)
    correlation_id || SecureRandom.uuid
  end
end