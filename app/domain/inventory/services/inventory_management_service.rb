# frozen_string_literal: true

# Domain service for complex inventory management operations
# Contains business logic that doesn't naturally belong to a single entity
class InventoryManagementService
  # Synchronize inventory across all active channels for a product
  # @param product [Product] product to synchronize
  # @param channel_filter [SalesChannel, nil] specific channel to sync (nil for all)
  # @return [Hash] synchronization results
  def self.sync_product_inventory(product, channel_filter = nil)
    new.sync_product_inventory(product, channel_filter)
  end

  # Bulk reserve inventory across multiple products and channels
  # @param reservations [Array<Hash>] array of reservation requests
  # @return [Hash] bulk reservation results
  def self.bulk_reserve_inventory(reservations)
    new.bulk_reserve_inventory(reservations)
  end

  # Optimize inventory allocation based on business rules
  # @param product [Product] product to optimize allocation for
  # @param strategy [Symbol] optimization strategy
  # @return [Hash] optimization recommendations
  def self.optimize_allocation(product, strategy: :balanced)
    new.optimize_allocation(product, strategy)
  end

  # Calculate inventory health score for a product across channels
  # @param product [Product] product to assess
  # @return [Hash] health assessment
  def self.assess_inventory_health(product)
    new.assess_inventory_health(product)
  end

  # Initialize service with dependencies
  # @param inventory_repository [InventoryRepository] repository for inventory access
  # @param event_store [EventStore] store for domain events
  def initialize(inventory_repository: nil, event_store: nil)
    @inventory_repository = inventory_repository || InventoryRepository.new
    @event_store = event_store || EventStore.new
  end

  # Synchronize product inventory across channels
  # @param product [Product] product to synchronize
  # @param channel_filter [SalesChannel, nil] specific channel to sync
  # @return [Hash] synchronization results
  def sync_product_inventory(product, channel_filter = nil)
    results = {
      synchronized_channels: [],
      skipped_channels: [],
      errors: [],
      total_synced: 0
    }

    begin
      # Get channels to synchronize
      channels = determine_channels_to_sync(product, channel_filter)
      results[:total_channels] = channels.length

      # Sync each channel
      channels.each do |channel|
        sync_result = sync_single_channel(product, channel)
        if sync_result[:success]
          results[:synchronized_channels] << sync_result[:channel_id]
          results[:total_synced] += 1
        else
          results[:errors] << sync_result[:error]
        end
      end

    rescue => e
      results[:errors] << "Synchronization failed: #{e.message}"
    end

    results
  end

  # Bulk reserve inventory for multiple items
  # @param reservations [Array<Hash>] reservation specifications
  # @return [Hash] bulk operation results
  def bulk_reserve_inventory(reservations)
    results = {
      successful: [],
      failed: [],
      total_requested: reservations.length,
      total_reserved: 0
    }

    # Group reservations by product for efficient processing
    grouped_reservations = group_reservations_by_product(reservations)

    grouped_reservations.each do |product_id, product_reservations|
      bulk_result = process_bulk_reservations_for_product(product_id, product_reservations)
      results[:successful] += bulk_result[:successful]
      results[:failed] += bulk_result[:failed]
      results[:total_reserved] += bulk_result[:total_reserved]
    end

    results
  end

  # Optimize inventory allocation using specified strategy
  # @param product [Product] product to optimize
  # @param strategy [Symbol] optimization strategy
  # @return [Hash] optimization recommendations
  def optimize_allocation(product, strategy: :balanced)
    case strategy
    when :balanced
      balanced_allocation_strategy(product)
    when :demand_driven
      demand_driven_allocation_strategy(product)
    when :profit_maximizing
      profit_maximizing_allocation_strategy(product)
    when :risk_minimizing
      risk_minimizing_allocation_strategy(product)
    else
      raise ArgumentError, "Unknown optimization strategy: #{strategy}"
    end
  end

  # Assess overall inventory health for a product
  # @param product [Product] product to assess
  # @return [Hash] health assessment results
  def assess_inventory_health(product)
    inventories = @inventory_repository.find_by_product(product.id)
    return { health_score: 0, status: :no_inventory } if inventories.empty?

    assessments = inventories.map do |inventory|
      assess_single_inventory_health(inventory)
    end

    # Calculate aggregate health score
    total_score = assessments.sum { |a| a[:health_score] }
    average_score = total_score.to_f / assessments.length

    # Determine overall status
    critical_count = assessments.count { |a| a[:status] == :critical }
    warning_count = assessments.count { |a| a[:status] == :warning }

    overall_status = if critical_count > 0
                       :critical
                     elsif warning_count > assessments.length / 2
                       :warning
                     else
                       :healthy
                     end

    {
      health_score: average_score.round(2),
      status: overall_status,
      channel_assessments: assessments,
      recommendations: generate_health_recommendations(assessments),
      last_assessed: Time.current
    }
  end

  private

  # Determine which channels need synchronization
  # @param product [Product] product being synchronized
  # @param channel_filter [SalesChannel, nil] specific channel filter
  # @return [Array<SalesChannel>] channels to synchronize
  def determine_channels_to_sync(product, channel_filter)
    if channel_filter
      [channel_filter] if channel_filter.active?
    else
      SalesChannel.active_channels
    end
  end

  # Synchronize inventory for a single channel
  # @param product [Product] product to sync
  # @param channel [SalesChannel] channel to sync
  # @return [Hash] sync result for this channel
  def sync_single_channel(product, channel)
    begin
      # Get or create inventory record
      inventory = @inventory_repository.find_by_product_and_channel(product.id, channel.id)
      inventory ||= create_inventory_record(product, channel)

      # Check if sync is needed
      return { success: true, channel_id: channel.id, skipped: true } if sync_not_needed?(inventory)

      # Perform synchronization
      source_quantity = determine_source_quantity(product, channel)
      sync_result = inventory.sync_inventory(source_quantity, 'product_sync')

      if sync_result
        @event_store.append_events(inventory.id, inventory.uncommitted_events)
        inventory.mark_events_committed

        {
          success: true,
          channel_id: channel.id,
          quantity_synced: source_quantity,
          previous_quantity: inventory.quantity.value
        }
      else
        { success: false, channel_id: channel.id, error: 'Sync operation failed' }
      end

    rescue => e
      { success: false, channel_id: channel.id, error: e.message }
    end
  end

  # Create new inventory record for product/channel combination
  # @param product [Product] product for inventory
  # @param channel [SalesChannel] channel for inventory
  # @return [ChannelInventory] new inventory record
  def create_inventory_record(product, channel)
    inventory_id = generate_inventory_id(product.id, channel.id)

    # Load from events if exists, otherwise create new
    events = @event_store.get_events_for_aggregate(inventory_id)
    if events.any?
      ChannelInventory.from_events(inventory_id, events)
    else
      inventory = ChannelInventory.new(inventory_id, product.id, channel.id, product.stock_quantity || 0)
      @event_store.append_events(inventory_id, inventory.uncommitted_events)
      inventory.mark_events_committed
      inventory
    end
  end

  # Check if synchronization is needed
  # @param inventory [ChannelInventory] inventory to check
  # @return [Boolean] true if sync is not needed
  def sync_not_needed?(inventory)
    # Don't sync if recently synchronized (within last hour)
    return true if inventory.updated_at > 1.hour.ago

    # Don't sync if no quantity change
    false
  end

  # Determine source quantity for synchronization
  # @param product [Product] product being synchronized
  # @param channel [SalesChannel] target channel
  # @return [Integer] quantity to sync to
  def determine_source_quantity(product, channel)
    # Apply channel-specific business rules
    base_quantity = product.stock_quantity || 0

    # Apply channel multipliers or adjustments
    channel_multiplier = channel.inventory_multiplier || 1.0
    adjusted_quantity = (base_quantity * channel_multiplier).to_i

    # Ensure non-negative
    [adjusted_quantity, 0].max
  end

  # Group reservations by product for efficient processing
  # @param reservations [Array<Hash>] reservation requests
  # @return [Hash] grouped reservations
  def group_reservations_by_product(reservations)
    reservations.group_by { |r| r[:product_id] }
  end

  # Process bulk reservations for a single product
  # @param product_id [Integer] product ID
  # @param product_reservations [Array<Hash>] reservations for this product
  # @return [Hash] processing results
  def process_bulk_reservations_for_product(product_id, product_reservations)
    results = { successful: [], failed: [], total_reserved: 0 }

    # Check if we can fulfill all reservations for this product
    total_requested = product_reservations.sum { |r| r[:quantity] }

    # Get inventory for primary channel (or determine appropriate channel)
    primary_channel_id = determine_primary_channel_for_product(product_id)
    inventory = @inventory_repository.find_by_product_and_channel(product_id, primary_channel_id)

    if inventory.nil?
      # No inventory available
      product_reservations.each do |reservation|
        results[:failed] << {
          product_id: product_id,
          channel_id: reservation[:channel_id],
          quantity: reservation[:quantity],
          reason: 'No inventory record found'
        }
      end
      return results
    end

    # Check if inventory can fulfill total request
    fulfillment_check = inventory.can_fulfill?(total_requested)
    unless fulfillment_check[:can_fulfill]
      # Cannot fulfill all requests
      product_reservations.each do |reservation|
        results[:failed] << {
          product_id: product_id,
          channel_id: reservation[:channel_id],
          quantity: reservation[:quantity],
          reason: fulfillment_check[:reason]
        }
      end
      return results
    end

    # Process individual reservations
    product_reservations.each do |reservation|
      begin
        # Get inventory for specific channel
        channel_inventory = @inventory_repository.find_by_product_and_channel(
          product_id,
          reservation[:channel_id]
        )

        if channel_inventory.nil?
          results[:failed] << {
            product_id: product_id,
            channel_id: reservation[:channel_id],
            quantity: reservation[:quantity],
            reason: 'No inventory for channel'
          }
          next
        end

        # Attempt reservation
        if channel_inventory.reserve_inventory(
          reservation[:quantity],
          order_id: reservation[:order_id],
          expires_at: reservation[:expires_at]
        )
          @event_store.append_events(channel_inventory.id, channel_inventory.uncommitted_events)
          channel_inventory.mark_events_committed

          results[:successful] << {
            product_id: product_id,
            channel_id: reservation[:channel_id],
            quantity: reservation[:quantity],
            inventory_id: channel_inventory.id
          }
          results[:total_reserved] += reservation[:quantity]
        else
          results[:failed] << {
            product_id: product_id,
            channel_id: reservation[:channel_id],
            quantity: reservation[:quantity],
            reason: 'Reservation failed'
          }
        end

      rescue => e
        results[:failed] << {
          product_id: product_id,
          channel_id: reservation[:channel_id],
          quantity: reservation[:quantity],
          reason: e.message
        }
      end
    end

    results
  end

  # Determine primary channel for a product
  # @param product_id [Integer] product ID
  # @return [Integer] primary channel ID
  def determine_primary_channel_for_product(product_id)
    # This would typically use business rules to determine the primary channel
    # For now, return the first active channel
    SalesChannel.active_channels.first&.id || 1
  end

  # Generate unique inventory ID
  # @param product_id [Integer] product ID
  # @param channel_id [Integer] channel ID
  # @return [String] unique inventory ID
  def generate_inventory_id(product_id, channel_id)
    "inventory_#{product_id}_#{channel_id}_#{Time.current.to_i}"
  end

  # Balanced allocation strategy - distributes inventory evenly
  # @param product [Product] product to optimize
  # @return [Hash] optimization recommendations
  def balanced_allocation_strategy(product)
    inventories = @inventory_repository.find_by_product(product.id)
    return { strategy: :none, recommendations: [] } if inventories.empty?

    # Calculate optimal distribution
    total_quantity = inventories.sum(&:quantity)
    channel_count = inventories.length
    optimal_per_channel = total_quantity / channel_count

    recommendations = inventories.map do |inventory|
      current_quantity = inventory.quantity.value
      recommended_quantity = optimal_per_channel

      if current_quantity < recommended_quantity * 0.8
        {
          channel_id: inventory.sales_channel_id,
          action: :increase,
          current_quantity: current_quantity,
          recommended_quantity: recommended_quantity,
          priority: :high
        }
      elsif current_quantity > recommended_quantity * 1.2
        {
          channel_id: inventory.sales_channel_id,
          action: :decrease,
          current_quantity: current_quantity,
          recommended_quantity: recommended_quantity,
          priority: :medium
        }
      else
        {
          channel_id: inventory.sales_channel_id,
          action: :maintain,
          current_quantity: current_quantity,
          recommended_quantity: current_quantity,
          priority: :low
        }
      end
    end

    {
      strategy: :balanced,
      recommendations: recommendations,
      total_quantity: total_quantity,
      channel_count: channel_count
    }
  end

  # Demand-driven allocation strategy
  # @param product [Product] product to optimize
  # @return [Hash] optimization recommendations
  def demand_driven_allocation_strategy(product)
    # Analyze historical demand patterns and allocate accordingly
    # This would typically use machine learning models

    {
      strategy: :demand_driven,
      recommendations: [],
      note: 'Demand-driven optimization requires historical data analysis'
    }
  end

  # Profit-maximizing allocation strategy
  # @param product [Product] product to optimize
  # @return [Hash] optimization recommendations
  def profit_maximizing_allocation_strategy(product)
    # Allocate more inventory to high-margin channels
    # This would use pricing and margin data

    {
      strategy: :profit_maximizing,
      recommendations: [],
      note: 'Profit optimization requires margin and pricing data'
    }
  end

  # Risk-minimizing allocation strategy
  # @param product [Product] product to optimize
  # @return [Hash] optimization recommendations
  def risk_minimizing_allocation_strategy(product)
    # Allocate conservatively to minimize stockout risk
    # This would use risk assessment models

    {
      strategy: :risk_minimizing,
      recommendations: [],
      note: 'Risk minimization requires risk assessment models'
    }
  end

  # Assess health of a single inventory record
  # @param inventory [ChannelInventory] inventory to assess
  # @return [Hash] health assessment
  def assess_single_inventory_health(inventory)
    score_components = {
      quantity_health: calculate_quantity_health_score(inventory),
      status_health: calculate_status_health_score(inventory),
      utilization_health: calculate_utilization_health_score(inventory),
      recency_health: calculate_recency_health_score(inventory)
    }

    # Calculate weighted overall score
    weights = { quantity_health: 0.3, status_health: 0.4, utilization_health: 0.2, recency_health: 0.1 }
    overall_score = score_components.sum { |component, score| score * weights[component] }

    # Determine status based on score
    status = case overall_score
             when 80..100 then :excellent
             when 60..79 then :good
             when 40..59 then :warning
             else :critical
             end

    {
      inventory_id: inventory.id,
      channel_id: inventory.sales_channel_id,
      health_score: overall_score.round(2),
      status: status,
      components: score_components,
      issues: identify_health_issues(inventory, score_components)
    }
  end

  # Calculate quantity-based health score
  # @param inventory [ChannelInventory] inventory to assess
  # @return [Float] health score (0-100)
  def calculate_quantity_health_score(inventory)
    quantity = inventory.quantity.value

    case quantity
    when 0 then 0
    when 1..10 then 30
    when 11..50 then 60
    when 51..100 then 80
    else 100
    end
  end

  # Calculate status-based health score
  # @param inventory [ChannelInventory] inventory to assess
  # @return [Float] health score (0-100)
  def calculate_status_health_score(inventory)
    case inventory.status.level
    when :out_of_stock then 0
    when :low_stock then 40
    when :in_stock then 80
    when :overstocked then 60
    else 50
    end
  end

  # Calculate utilization-based health score
  # @param inventory [ChannelInventory] inventory to assess
  # @return [Float] health score (0-100)
  def calculate_utilization_health_score(inventory)
    utilization = inventory.quantity.utilization_rate

    case utilization
    when 0.0..0.3 then 100 # Too low - not being used effectively
    when 0.3..0.7 then 80  # Optimal range
    when 0.7..0.9 then 60  # High utilization - monitor closely
    else 30 # Too high - risk of stockouts
    end
  end

  # Calculate recency-based health score
  # @param inventory [ChannelInventory] inventory to assess
  # @return [Float] health score (0-100)
  def calculate_recency_health_score(inventory)
    hours_since_update = (Time.current - inventory.updated_at) / 3600

    case hours_since_update
    when 0..1 then 100     # Recently updated
    when 1..24 then 80     # Updated today
    when 24..168 then 60   # Updated this week
    else 30               # Stale data
    end
  end

  # Identify specific health issues for an inventory
  # @param inventory [ChannelInventory] inventory to analyze
  # @param score_components [Hash] component scores
  # @return [Array<String>] list of identified issues
  def identify_health_issues(inventory, score_components)
    issues = []

    issues << 'Out of stock' if inventory.status.out_of_stock?
    issues << 'Low stock' if inventory.status.low_stock?
    issues << 'Overstocked' if inventory.status.overstocked?
    issues << 'High utilization rate' if inventory.quantity.utilization_rate > 0.8
    issues << 'Stale data' if inventory.updated_at < 24.hours.ago
    issues << 'No reservations' if inventory.quantity.reserved.zero?

    issues
  end

  # Generate health-based recommendations
  # @param assessments [Array<Hash>] individual assessments
  # @return [Array<String>] recommendations
  def generate_health_recommendations(assessments)
    recommendations = []

    critical_count = assessments.count { |a| a[:status] == :critical }
    if critical_count > 0
      recommendations << "#{critical_count} channel(s) need immediate attention"
    end

    low_stock_count = assessments.count { |a| a[:issues].include?('Low stock') }
    if low_stock_count > 0
      recommendations << "Schedule restock for #{low_stock_count} channel(s)"
    end

    overstocked_count = assessments.count { |a| a[:issues].include?('Overstocked') }
    if overstocked_count > 0
      recommendations << "Consider promotional activities for #{overstocked_count} overstocked channel(s)"
    end

    recommendations
  end
end