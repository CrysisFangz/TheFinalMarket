# Channel Product model for managing product availability across different sales channels.
# Follows Domain-Driven Design principles with separated concerns.
class ChannelProduct < ApplicationRecord
  belongs_to :sales_channel
  belongs_to :product

  validates :sales_channel, presence: true
  validates :product, presence: true
  validates :product_id, uniqueness: { scope: :sales_channel_id }

  scope :available, -> { where(available: true) }
  scope :unavailable, -> { where(available: false) }
  scope :active_channels, -> { joins(:sales_channel).where(sales_channels: { status: :active }) }
  scope :online_channels, -> { joins(:sales_channel).where(sales_channels: { channel_type: [:web, :mobile_app, :marketplace] }) }
  scope :recently_synced, -> { where('last_synced_at > ?', 1.hour.ago) }

  # Value objects for business logic
  def pricing
    @pricing ||= ChannelProduct::ValueObjects::ChannelPricing.from_product_and_channel(
      product.price,
      pricing_config
    )
  end

  def inventory
    @inventory ||= ChannelProduct::ValueObjects::ChannelInventory.from_product_and_channel(
      product.stock_quantity,
      inventory_config
    )
  end

  # Business logic delegation
  def effective_price
    pricing.effective_price
  end

  def effective_inventory
    inventory.effective_stock_quantity
  end

  def available_for_purchase?
    available? && inventory.available_quantity > 0 && product_in_stock?
  end

  def channel_title
    channel_specific_data&.dig('title') || product.name
  end

  def channel_description
    channel_specific_data&.dig('description') || product.description
  end

  def channel_images
    channel_specific_data&.dig('images') || []
  end

  # Synchronization operations using domain services
  def sync_from_product!(sync_context = {})
    synchronization_service.synchronize_from_product(self, sync_context)
    reload
    self
  end

  def sync_inventory!(inventory_data, update_context = {})
    synchronization_service.synchronize_inventory_update(
      self,
      inventory_data,
      update_context
    )
    reload
    self
  end

  def sync_pricing!(pricing_data, update_context = {})
    synchronization_service.synchronize_price_update(
      self,
      pricing_data,
      update_context
    )
    reload
    self
  end

  # Performance analytics using domain services
  def performance_metrics(time_range = 30.days)
    performance_service.calculate_performance_metrics(
      self,
      time_range: time_range,
      context: { include_predictions: true }
    )
  end

  def comparative_performance_metrics(comparison_periods = [7.days, 90.days])
    performance_service.calculate_comparative_metrics(
      self,
      comparison_periods: comparison_periods,
      context: { include_trends: true }
    )
  end

  def predictive_performance_metrics(forecast_days = 30)
    performance_service.calculate_predictive_metrics(
      self,
      forecast_days: forecast_days,
      context: { confidence_threshold: 0.8 }
    )
  end

  # Channel data management
  def update_channel_data(data)
    ChannelProduct::Services::ChannelDataService.new.update_data(self, data)
  end

  def clear_channel_data_override
    update!(channel_specific_data: {})
    publish_channel_data_cleared_event
    true
  end

  # Availability management
  def mark_as_available!
    update!(available: true, availability_updated_at: Time.current)
    publish_availability_changed_event(true)
    true
  end

  def mark_as_unavailable!
    update!(available: false, availability_updated_at: Time.current)
    publish_availability_changed_event(false)
    true
  end

  # Business intelligence
  def business_insights(time_range = 30.days)
    performance_service.generate_business_insights(
      self,
      insight_context: {
        time_range: time_range,
        include_recommendations: true,
        include_risk_assessment: true
      }
    )
  end

  def optimization_strategy(optimization_goals = {})
    performance_service.optimize_performance_strategy(
      self,
      optimization_goals: optimization_goals
    )
  end

  # Real-time monitoring
  def monitor_performance(monitoring_context = {})
    performance_service.monitor_real_time_performance(
      self,
      monitoring_context: monitoring_context
    )
  end

  # Bulk operations
  def self.bulk_sync_from_products(product_ids, sync_context = {})
    ChannelProduct::Services::BulkSynchronizationService.new.bulk_sync(product_ids, sync_context)
  end

  def self.calculate_channel_analytics(sales_channel, time_range = 30.days)
    performance_service.calculate_channel_analytics(
      sales_channel,
      time_range: time_range,
      context: { include_ml_insights: true }
    )
  end

  def self.calculate_product_analytics(product, time_range = 30.days)
    performance_service.calculate_product_analytics(
      product,
      time_range: time_range,
      context: { include_cross_channel: true }
    )
  end

  # Configuration
  def pricing_config
    sales_channel.configuration[:pricing] || {}
  end

  def inventory_config
    sales_channel.configuration[:inventory] || {}
  end

  def channel_capabilities
    sales_channel.configuration[:capabilities] || {}
  end

  # Health checks
  def health_check
    ChannelProduct::Services::HealthCheckService.new.check_health(self)
  end

  private

  def synchronization_service
    @synchronization_service ||= ChannelProduct::Services::ChannelProductSynchronizationService.new
  end

  def performance_service
    @performance_service ||= ChannelProduct::Services::ChannelProductPerformanceService.new
  end

  def product_in_stock?
    product&.stock_quantity.to_i > 0
  rescue
    false
  end

  def publish_channel_data_cleared_event
    EventStore::Repository.new.publish(
      ChannelDataCleared.new(
        channel_product_id: id,
        timestamp: Time.current
      )
    )
  rescue => e
    Rails.logger.error("Failed to publish channel data cleared event: #{e.message}")
  end

  def publish_availability_changed_event(available)
    EventStore::Repository.new.publish(
      AvailabilityChanged.new(
        channel_product_id: id,
        available: available,
        timestamp: Time.current
      )
    )
  rescue => e
    Rails.logger.error("Failed to publish availability event: #{e.message}")
  end

  def invalidate_instance_cache
    @pricing = nil
    @inventory = nil
  end

  # Event classes for domain events
  class ChannelDataCleared < RailsEventStore::Event
    def self.strict; end
  end

  class AvailabilityChanged < RailsEventStore::Event
    def self.strict; end
  end
end