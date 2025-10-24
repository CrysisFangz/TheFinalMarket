class SalesChannel < ApplicationRecord
  has_many :channel_products
  has_many :products, through: :channel_products
  has_many :orders
  has_many :channel_inventories
  has_many :channel_analytics
  has_many :channel_integrations
  
  validates :name, presence: true
  validates :channel_type, presence: true
  validates :status, presence: true
  
  enum channel_type: {
    web: 0,
    mobile_app: 1,
    marketplace: 2,
    social_media: 3,
    physical_store: 4,
    phone: 5,
    email: 6,
    chat: 7,
    voice_assistant: 8,
    kiosk: 9
  }
  
  enum status: {
    active: 0,
    inactive: 1,
    maintenance: 2,
    testing: 3
  }
  
  # Scopes
  scope :active_channels, -> { where(status: :active) }
  scope :online_channels, -> { where(channel_type: [:web, :mobile_app, :marketplace, :social_media]) }
  scope :offline_channels, -> { where(channel_type: [:physical_store, :phone, :kiosk]) }
  
  # Delegated to SalesChannelConfigurationService
  def configuration
    @config_service ||= SalesChannelConfigurationService.new(self)
    @config_service.configuration
  end

  def update_configuration(new_config)
    @config_service ||= SalesChannelConfigurationService.new(self)
    @config_service.update_configuration(new_config)
  end
  
  # Delegated to SalesChannelPerformanceService
  def performance_metrics(start_date: 30.days.ago, end_date: Time.current)
    @performance_service ||= SalesChannelPerformanceService.new(self)
    @performance_service.performance_metrics(start_date: start_date, end_date: end_date)
  end
  
  # Delegated to SalesChannelInventoryService
  def sync_inventory!
    @inventory_service ||= SalesChannelInventoryService.new(self)
    @inventory_service.sync_inventory!
  end

  def available_products
    @inventory_service ||= SalesChannelInventoryService.new(self)
    @inventory_service.available_products
  end
  
  # Delegated to SalesChannelProductService
  def add_product(product, options = {})
    @product_service ||= SalesChannelProductService.new(self)
    @product_service.add_product(product, options)
  end

  def remove_product(product)
    @product_service ||= SalesChannelProductService.new(self)
    @product_service.remove_product(product)
  end

  def get_price(product)
    @product_service ||= SalesChannelProductService.new(self)
    @product_service.get_price(product)
  end

  def product_available?(product)
    @product_service ||= SalesChannelProductService.new(self)
    @product_service.product_available?(product)
  end
  
  # Delegated to SalesChannelAnalyticsService
  def statistics
    @analytics_service ||= SalesChannelAnalyticsService.new(self)
    @analytics_service.statistics
  end
  
  # Delegated to SalesChannelIntegrationService
  def integration_status
    @integration_service ||= SalesChannelIntegrationService.new(self)
    @integration_service.integration_status
  end
  
  # Enable channel
  def enable!
    update!(status: :active, enabled_at: Time.current)
  end
  
  # Disable channel
  def disable!
    update!(status: :inactive, disabled_at: Time.current)
  end
  
  # Delegated to SalesChannelAnalyticsService
  def health_check
    @analytics_service ||= SalesChannelAnalyticsService.new(self)
    @analytics_service.health_check
  end
  
  private

  # Default configuration is now handled in SalesChannelConfigurationService
end

