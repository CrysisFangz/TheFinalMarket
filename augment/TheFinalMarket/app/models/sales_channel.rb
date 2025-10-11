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
  
  # Get channel configuration
  def configuration
    config_data || default_configuration
  end
  
  # Update channel configuration
  def update_configuration(new_config)
    update!(config_data: configuration.merge(new_config))
  end
  
  # Get channel performance
  def performance_metrics(start_date: 30.days.ago, end_date: Time.current)
    analytics = channel_analytics.where(date: start_date..end_date)
    
    {
      total_orders: analytics.sum(:orders_count),
      total_revenue: analytics.sum(:revenue),
      average_order_value: analytics.average(:average_order_value).to_f.round(2),
      conversion_rate: analytics.average(:conversion_rate).to_f.round(2),
      customer_count: analytics.sum(:unique_customers),
      return_rate: analytics.average(:return_rate).to_f.round(2)
    }
  end
  
  # Sync inventory across channels
  def sync_inventory!
    products.find_each do |product|
      ChannelInventory.sync_for_product(product, self)
    end
  end
  
  # Get available products
  def available_products
    channel_products.where(available: true).includes(:product)
  end
  
  # Add product to channel
  def add_product(product, options = {})
    channel_products.create!(
      product: product,
      available: options[:available] != false,
      price_override: options[:price_override],
      inventory_override: options[:inventory_override],
      channel_specific_data: options[:channel_data] || {}
    )
  end
  
  # Remove product from channel
  def remove_product(product)
    channel_products.find_by(product: product)&.destroy
  end
  
  # Get channel-specific pricing
  def get_price(product)
    channel_product = channel_products.find_by(product: product)
    channel_product&.price_override || product.price
  end
  
  # Check if product is available
  def product_available?(product)
    channel_product = channel_products.find_by(product: product)
    channel_product&.available? && channel_product.product.in_stock?
  end
  
  # Get channel statistics
  def statistics
    {
      total_products: channel_products.count,
      available_products: channel_products.where(available: true).count,
      total_orders: orders.count,
      pending_orders: orders.where(status: 'pending').count,
      completed_orders: orders.where(status: 'completed').count,
      total_revenue: orders.where(status: 'completed').sum(:total),
      active_customers: orders.distinct.count(:user_id)
    }
  end
  
  # Integration status
  def integration_status
    integration = channel_integrations.active.first
    
    if integration
      {
        connected: true,
        platform: integration.platform_name,
        last_sync: integration.last_sync_at,
        sync_status: integration.sync_status,
        errors: integration.error_count
      }
    else
      {
        connected: false,
        platform: nil,
        last_sync: nil,
        sync_status: 'not_configured',
        errors: 0
      }
    end
  end
  
  # Enable channel
  def enable!
    update!(status: :active, enabled_at: Time.current)
  end
  
  # Disable channel
  def disable!
    update!(status: :inactive, disabled_at: Time.current)
  end
  
  # Channel health check
  def health_check
    issues = []
    
    issues << 'No products available' if channel_products.where(available: true).count.zero?
    issues << 'No recent orders' if orders.where('created_at > ?', 7.days.ago).count.zero?
    issues << 'Integration errors' if channel_integrations.active.any? { |i| i.error_count > 0 }
    issues << 'Low inventory' if channel_inventories.where('quantity < 10').count > 10
    
    {
      healthy: issues.empty?,
      issues: issues,
      last_checked: Time.current
    }
  end
  
  private
  
  def default_configuration
    {
      currency: 'USD',
      language: 'en',
      tax_included: false,
      shipping_enabled: true,
      payment_methods: ['credit_card', 'paypal'],
      fulfillment_method: 'standard'
    }
  end
end

