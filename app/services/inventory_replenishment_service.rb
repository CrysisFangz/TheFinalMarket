# frozen_string_literal: true

class InventoryReplenishmentService
  def initialize(inventory)
    @inventory = inventory
  end

  def add(amount, source: 'manual', correlation_id: nil, metadata: {})
    return false if amount <= 0

    operation_id = generate_operation_id(correlation_id)

    begin
      domain_entity = @inventory.load_or_create_domain_entity

      replenishment_success = domain_entity.replenish_inventory(amount, source: source)

      if replenishment_success
        @inventory.record_supply_chain_event(:replenishment, amount, source, metadata)
        @inventory.apply_domain_events(domain_entity.uncommitted_events)
        @inventory.record_successful_operation(:replenishment, amount, operation_id)
        @inventory.broadcast_inventory_update
        return true
      end

      false
    rescue => e
      @inventory.record_failed_operation(:replenishment, amount, :exception, e.message)
      false
    end
  end

  private

  def generate_operation_id(correlation_id)
    correlation_id || SecureRandom.uuid
  end
end