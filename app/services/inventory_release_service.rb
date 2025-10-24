# frozen_string_literal: true

class InventoryReleaseService
  def initialize(inventory)
    @inventory = inventory
  end

  def release(amount, order_id: nil, reason: :manual, correlation_id: nil)
    actual_release = [amount, @inventory.reserved_quantity].min
    return false if actual_release.zero?

    operation_id = generate_operation_id(correlation_id)

    begin
      domain_entity = @inventory.load_or_create_domain_entity

      release_success = domain_entity.release_inventory(actual_release, order_id: order_id)

      if release_success
        @inventory.apply_domain_events(domain_entity.uncommitted_events)
        @inventory.record_successful_operation(:release, actual_release, operation_id)
        @inventory.broadcast_inventory_update
        return true
      end

      false
    rescue => e
      @inventory.record_failed_operation(:release, amount, :exception, e.message)
      false
    end
  end

  private

  def generate_operation_id(correlation_id)
    correlation_id || SecureRandom.uuid
  end
end