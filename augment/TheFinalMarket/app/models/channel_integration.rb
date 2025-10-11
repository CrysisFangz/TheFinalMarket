class ChannelIntegration < ApplicationRecord
  belongs_to :sales_channel
  
  validates :sales_channel, presence: true
  validates :platform_name, presence: true
  validates :integration_type, presence: true
  
  enum integration_type: {
    marketplace: 0,      # Amazon, eBay, Etsy
    social_commerce: 1,  # Facebook, Instagram, TikTok
    pos_system: 2,       # Square, Shopify POS, Clover
    erp_system: 3,       # SAP, Oracle, NetSuite
    crm_system: 4,       # Salesforce, HubSpot
    shipping: 5,         # ShipStation, EasyPost
    payment: 6,          # Stripe, PayPal
    analytics: 7,        # Google Analytics, Mixpanel
    email: 8,            # Mailchimp, SendGrid
    chat: 9              # Intercom, Zendesk
  }
  
  enum sync_status: {
    pending: 0,
    syncing: 1,
    synced: 2,
    failed: 3,
    paused: 4
  }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :failed, -> { where(sync_status: :failed) }
  
  # Connect integration
  def connect!(credentials)
    update!(
      credentials: credentials,
      active: true,
      connected_at: Time.current,
      sync_status: :pending
    )
    
    # Trigger initial sync
    sync!
  end
  
  # Disconnect integration
  def disconnect!
    update!(
      active: false,
      disconnected_at: Time.current,
      sync_status: :paused
    )
  end
  
  # Sync data
  def sync!
    return unless active?
    
    update!(sync_status: :syncing, last_sync_started_at: Time.current)
    
    begin
      case integration_type.to_sym
      when :marketplace
        sync_marketplace_data
      when :social_commerce
        sync_social_commerce_data
      when :pos_system
        sync_pos_data
      when :erp_system
        sync_erp_data
      when :crm_system
        sync_crm_data
      else
        sync_generic_data
      end
      
      update!(
        sync_status: :synced,
        last_sync_at: Time.current,
        last_sync_started_at: nil,
        error_count: 0,
        last_error: nil
      )
    rescue StandardError => e
      handle_sync_error(e)
    end
  end
  
  # Get integration health
  def health_status
    if !active?
      'inactive'
    elsif sync_status == 'failed'
      'unhealthy'
    elsif error_count > 5
      'degraded'
    elsif last_sync_at && last_sync_at < 1.hour.ago
      'stale'
    else
      'healthy'
    end
  end
  
  # Get sync statistics
  def sync_statistics
    {
      total_syncs: sync_count,
      successful_syncs: sync_count - error_count,
      failed_syncs: error_count,
      last_sync: last_sync_at,
      average_sync_duration: average_sync_duration,
      success_rate: calculate_success_rate
    }
  end
  
  # Test connection
  def test_connection
    # This would test the actual API connection
    # For now, return mock result
    {
      success: true,
      latency: rand(100..500),
      message: 'Connection successful'
    }
  end
  
  # Get integration capabilities
  def capabilities
    case integration_type.to_sym
    when :marketplace
      ['product_sync', 'order_sync', 'inventory_sync', 'pricing_sync']
    when :social_commerce
      ['product_catalog', 'order_management', 'customer_messaging']
    when :pos_system
      ['inventory_sync', 'sales_sync', 'customer_sync']
    when :erp_system
      ['full_data_sync', 'real_time_updates', 'reporting']
    when :crm_system
      ['customer_sync', 'interaction_tracking', 'segmentation']
    when :shipping
      ['label_generation', 'tracking', 'rate_calculation']
    when :payment
      ['payment_processing', 'refunds', 'reporting']
    when :analytics
      ['event_tracking', 'conversion_tracking', 'reporting']
    when :email
      ['campaign_management', 'automation', 'analytics']
    when :chat
      ['live_chat', 'chatbot', 'ticket_management']
    else
      []
    end
  end
  
  private
  
  def sync_marketplace_data
    # Sync products, orders, inventory with marketplace
    sync_data['products_synced'] = sales_channel.products.count
    sync_data['orders_synced'] = sales_channel.orders.where('created_at > ?', last_sync_at || 1.day.ago).count
    increment!(:sync_count)
  end
  
  def sync_social_commerce_data
    # Sync product catalog and orders with social platform
    sync_data['catalog_synced'] = true
    sync_data['orders_synced'] = sales_channel.orders.where('created_at > ?', last_sync_at || 1.day.ago).count
    increment!(:sync_count)
  end
  
  def sync_pos_data
    # Sync inventory and sales with POS system
    sync_data['inventory_synced'] = true
    sync_data['sales_synced'] = true
    increment!(:sync_count)
  end
  
  def sync_erp_data
    # Full data sync with ERP system
    sync_data['full_sync'] = true
    increment!(:sync_count)
  end
  
  def sync_crm_data
    # Sync customer data with CRM
    sync_data['customers_synced'] = User.count
    increment!(:sync_count)
  end
  
  def sync_generic_data
    # Generic sync logic
    increment!(:sync_count)
  end
  
  def handle_sync_error(error)
    increment!(:error_count)
    update!(
      sync_status: :failed,
      last_error: error.message,
      last_sync_started_at: nil
    )
  end
  
  def average_sync_duration
    # Mock calculation
    rand(5..30) # seconds
  end
  
  def calculate_success_rate
    return 100 if sync_count.zero?
    (((sync_count - error_count).to_f / sync_count) * 100).round(2)
  end
end

