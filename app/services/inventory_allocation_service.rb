# frozen_string_literal: true

class InventoryAllocationService
  def initialize(inventory)
    @inventory = inventory
  end

  def allocate(amount, order_id:, shipment_id: nil, correlation_id: nil)
    return false if amount <= 0 || @inventory.quantity < amount

    operation_id = generate_operation_id(correlation_id)

    begin
      domain_entity = @inventory.load_or_create_domain_entity

      allocation_success = domain_entity.allocate_inventory(amount, order_id, shipment_id: shipment_id)

      if allocation_success
        @inventory.apply_domain_events(domain_entity.uncommitted_events)
        @inventory.record_successful_operation(:allocation, amount, operation_id)
        @inventory.broadcast_inventory_update
        return true
      end

      false
    rescue => e
      @inventory.record_failed_operation(:allocation, amount, :exception, e.message)
      false
    end
  end

  private

  def generate_operation_id(correlation_id)
    correlation_id || SecureRandom.uuid
  end
end