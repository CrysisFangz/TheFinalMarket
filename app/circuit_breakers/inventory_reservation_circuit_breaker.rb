# frozen_string_literal: true

module CircuitBreakers
  class InventoryReservationCircuitBreaker < BaseCircuitBreaker
    def initialize
      super('InventoryReservation', failure_threshold: 3, recovery_timeout: 30)
    end
  end
end