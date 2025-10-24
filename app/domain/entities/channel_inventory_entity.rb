# frozen_string_literal: true

module Domain
  module Entities
    class ChannelInventoryEntity
      include ActiveModel::Validations

      attr_reader :id, :product_id, :sales_channel_id, :quantity, :reserved_quantity, :allocated_quantity,
                  :uncommitted_events, :version

      def initialize(id, product_id, sales_channel_id, quantity, reserved_quantity = 0, allocated_quantity = 0, version = 1)
        @id = id
        @product_id = product_id
        @sales_channel_id = sales_channel_id
        @quantity = quantity
        @reserved_quantity = reserved_quantity
        @allocated_quantity = allocated_quantity
        @version = version
        @uncommitted_events = []
      end

      def available_quantity
        quantity - reserved_quantity - allocated_quantity
      end

      def can_fulfill?(amount)
        if available_quantity >= amount
          { can_fulfill: true, utilization_impact: calculate_utilization_impact(amount) }
        else
          { can_fulfill: false, reason: :insufficient_stock }
        end
      end

      def reserve_inventory(amount, order_id: nil, expires_at: nil)
        return false unless can_fulfill?(amount)[:can_fulfill]

        @reserved_quantity += amount
        apply_event(Events::InventoryReserved.new(
          aggregate_id: id,
          amount: amount,
          order_id: order_id,
          expires_at: expires_at,
          reserved_after: reserved_quantity,
          version: next_version
        ))
        true
      end

      def release_inventory(amount, order_id: nil)
        actual_release = [amount, reserved_quantity].min
        return false if actual_release.zero?

        @reserved_quantity -= actual_release
        apply_event(Events::InventoryReleased.new(
          aggregate_id: id,
          amount: actual_release,
          order_id: order_id,
          reserved_after: reserved_quantity,
          version: next_version
        ))
        true
      end

      def allocate_inventory(amount, order_id, shipment_id: nil)
        return false if available_quantity < amount

        @allocated_quantity += amount
        apply_event(Events::InventoryAllocated.new(
          aggregate_id: id,
          amount: amount,
          order_id: order_id,
          shipment_id: shipment_id,
          allocated_after: allocated_quantity,
          version: next_version
        ))
        true
      end

      def replenish_inventory(amount, source: 'manual')
        @quantity += amount
        apply_event(Events::InventoryReplenished.new(
          aggregate_id: id,
          amount: amount,
          source: source,
          quantity_after: quantity,
          version: next_version
        ))
        true
      end

      def sync_inventory(new_quantity, source: 'external')
        previous_quantity = quantity
        delta = new_quantity - previous_quantity
        @quantity = new_quantity
        apply_event(Events::InventorySynced.new(
          aggregate_id: id,
          previous_quantity: previous_quantity,
          new_quantity: new_quantity,
          sync_delta: delta,
          source: source,
          version: next_version
        ))
        true
      end

      def summary
        {
          quantity: { value: quantity, reserved: reserved_quantity, allocated: allocated_quantity, available: available_quantity },
          status: determine_status,
          version: version
        }
      end

      def attention_needed?
        reasons = []
        reasons << :out_of_stock if available_quantity <= 0
        reasons << :low_stock if available_quantity < 10  # Simplified threshold
        { needs_attention: reasons.any?, reasons: reasons, priority: reasons.size }
      end

      def valid?
        super && quantity >= 0 && reserved_quantity >= 0 && allocated_quantity >= 0
      end

      def mark_events_committed
        @uncommitted_events.clear
      end

      def self.from_events(aggregate_id, events)
        entity = new(aggregate_id, 0, 0, 0)  # Initial state
        events.each do |event|
          entity.apply_event_from_store(event)
        end
        entity
      end

      def apply_event_from_store(event)
        case event.event_type
        when 'Domain::Events::InventoryReserved'
          @reserved_quantity += event.amount
        when 'Domain::Events::InventoryReleased'
          @reserved_quantity -= event.amount
        when 'Domain::Events::InventoryAllocated'
          @allocated_quantity += event.amount
        when 'Domain::Events::InventoryReplenished'
          @quantity += event.amount
        when 'Domain::Events::InventorySynced'
          @quantity = event.new_quantity
        end
        @version = event.version
      end

      private

      def apply_event(event)
        @uncommitted_events << event
        @version = event.version
      end

      def next_version
        version + 1
      end

      def determine_status
        if available_quantity <= 0
          :out_of_stock
        elsif available_quantity < 10
          :low_stock
        else
          :in_stock
        end
      end

      def calculate_utilization_impact(amount)
        # Simplified calculation
        utilization = (amount.to_f / quantity) * 100
        { percentage: utilization, level: utilization > 50 ? :high : :low }
      end
    end
  end
end