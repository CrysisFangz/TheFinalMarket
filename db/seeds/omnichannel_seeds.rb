puts "🌐 Seeding Omnichannel Integration data..."

# Create Sales Channels
puts "  Creating sales channels..."

channels_data = [
  {
    name: 'Website',
    channel_type: :web,
    status: :active,
    description: 'Main e-commerce website',
    config_data: {
      currency: 'USD',
      language: 'en',
      tax_included: false,
      shipping_enabled: true,
      payment_methods: ['credit_card', 'paypal', 'crypto']
    }
  },
  {
    name: 'Mobile App',
    channel_type: :mobile_app,
    status: :active,
    description: 'iOS and Android mobile application',
    config_data: {
      currency: 'USD',
      language: 'en',
      push_notifications: true,
      biometric_auth: true
    }
  },
  {
    name: 'Amazon Marketplace',
    channel_type: :marketplace,
    status: :active,
    description: 'Amazon marketplace integration',
    config_data: {
      marketplace_id: 'ATVPDKIKX0DER',
      fulfillment: 'FBA'
    }
  },
  {
    name: 'Instagram Shop',
    channel_type: :social_media,
    status: :active,
    description: 'Instagram shopping integration',
    config_data: {
      platform: 'instagram',
      catalog_sync: true
    }
  },
  {
    name: 'Physical Store - NYC',
    channel_type: :physical_store,
    status: :active,
    description: 'Flagship store in New York City',
    config_data: {
      address: '123 Main St, New York, NY 10001',
      hours: '9 AM - 9 PM',
      pos_system: 'Square'
    }
  },
  {
    name: 'Phone Orders',
    channel_type: :phone,
    status: :active,
    description: 'Customer service phone orders',
    config_data: {
      phone: '1-800-SHOP-NOW',
      hours: '24/7'
    }
  },
  {
    name: 'Email Orders',
    channel_type: :email,
    status: :active,
    description: 'Email-based ordering system',
    config_data: {
      email: 'orders@thefinalmarket.com'
    }
  },
  {
    name: 'Live Chat',
    channel_type: :chat,
    status: :active,
    description: 'Live chat support and sales',
    config_data: {
      platform: 'Intercom',
      availability: '24/7'
    }
  }
]

channels = channels_data.map do |data|
  SalesChannel.create!(data)
end

puts "    ✅ Created #{channels.count} sales channels"

# Add products to channels
puts "  Adding products to channels..."
products = Product.limit(50)
channel_product_count = 0

channels.each do |channel|
  # Add different products to different channels
  products_to_add = case channel.channel_type.to_sym
  when :web, :mobile_app
    products # All products
  when :marketplace
    products.sample(30) # 30 products
  when :social_media
    products.sample(20) # 20 products
  when :physical_store
    products.sample(40) # 40 products
  else
    products.sample(15) # 15 products
  end
  
  products_to_add.each do |product|
    channel.add_product(product, {
      available: true,
      price_override: channel.marketplace? ? product.price * 1.1 : nil # 10% markup on marketplace
    })
    channel_product_count += 1
  end
end

puts "    ✅ Created #{channel_product_count} channel-product associations"

# Sync inventory
puts "  Syncing inventory across channels..."
inventory_count = 0

products.each do |product|
  channels.each do |channel|
    next unless channel.channel_products.exists?(product: product)
    
    ChannelInventory.create!(
      sales_channel: channel,
      product: product,
      quantity: product.stock_quantity || rand(10..100),
      reserved_quantity: rand(0..5),
      low_stock_threshold: 10
    )
    inventory_count += 1
  end
end

puts "    ✅ Created #{inventory_count} inventory records"

# Create Omnichannel Customers
puts "  Creating omnichannel customer profiles..."
users = User.limit(30)
omnichannel_count = 0

users.each do |user|
  OmnichannelCustomer.create!(
    user: user,
    last_interaction_at: rand(1..30).days.ago,
    unified_data: {
      total_orders: rand(1..20),
      total_spent: rand(100..5000),
      favorite_channel: channels.sample.name
    }
  )
  omnichannel_count += 1
end

puts "    ✅ Created #{omnichannel_count} omnichannel customer profiles"

# Create Channel Interactions
puts "  Creating channel interactions..."
interaction_count = 0

OmnichannelCustomer.all.each do |customer|
  # Create 5-15 interactions per customer
  rand(5..15).times do
    customer.track_interaction(
      channels.sample,
      ChannelInteraction.interaction_types.keys.sample,
      {
        device: ['desktop', 'mobile', 'tablet'].sample,
        browser: ['Chrome', 'Safari', 'Firefox'].sample,
        location: ['New York', 'Los Angeles', 'Chicago'].sample
      }
    )
    interaction_count += 1
  end
end

puts "    ✅ Created #{interaction_count} channel interactions"

# Create Channel Preferences
puts "  Creating channel preferences..."
preference_count = 0

OmnichannelCustomer.all.each do |customer|
  # Create preferences for 2-4 channels
  channels.sample(rand(2..4)).each do |channel|
    ChannelPreference.create!(
      omnichannel_customer: customer,
      sales_channel: channel,
      preferences_data: {
        notifications: [true, false].sample,
        language: ['en', 'es', 'fr'].sample,
        currency: ['USD', 'EUR', 'GBP'].sample
      },
      last_synced_at: rand(1..7).days.ago
    )
    preference_count += 1
  end
end

puts "    ✅ Created #{preference_count} channel preferences"

# Create Cross-Channel Journeys
puts "  Creating cross-channel journeys..."
journey_count = 0

OmnichannelCustomer.all.each do |customer|
  # Create 2-5 journeys per customer
  rand(2..5).times do
    journey = customer.start_journey(
      channels.sample,
      CrossChannelJourney.intents.keys.sample
    )
    
    # Add 2-5 touchpoints
    rand(2..5).times do
      journey.add_touchpoint(
        channels.sample,
        ['view_product', 'add_to_cart', 'checkout', 'search', 'browse'].sample,
        { timestamp: Time.current }
      )
    end
    
    # Complete some journeys
    if rand < 0.7
      journey.complete!(['success', 'abandoned'].sample)
    end
    
    journey_count += 1
  end
end

puts "    ✅ Created #{journey_count} cross-channel journeys"

# Create Channel Integrations
puts "  Creating channel integrations..."
integration_count = 0

integration_data = [
  {
    channel: channels.find_by(name: 'Amazon Marketplace'),
    platform_name: 'Amazon MWS',
    integration_type: :marketplace,
    active: true
  },
  {
    channel: channels.find_by(name: 'Instagram Shop'),
    platform_name: 'Facebook Commerce',
    integration_type: :social_commerce,
    active: true
  },
  {
    channel: channels.find_by(name: 'Physical Store - NYC'),
    platform_name: 'Square POS',
    integration_type: :pos_system,
    active: true
  },
  {
    channel: channels.find_by(name: 'Website'),
    platform_name: 'Google Analytics',
    integration_type: :analytics,
    active: true
  },
  {
    channel: channels.find_by(name: 'Live Chat'),
    platform_name: 'Intercom',
    integration_type: :chat,
    active: true
  }
]

integration_data.each do |data|
  next unless data[:channel]
  
  integration = ChannelIntegration.create!(
    sales_channel: data[:channel],
    platform_name: data[:platform_name],
    integration_type: data[:integration_type],
    active: data[:active],
    sync_status: :synced,
    sync_count: rand(10..100),
    error_count: rand(0..2),
    connected_at: rand(30..90).days.ago,
    last_sync_at: rand(1..24).hours.ago
  )
  integration_count += 1
end

puts "    ✅ Created #{integration_count} channel integrations"

# Create Channel Analytics
puts "  Creating channel analytics..."
analytics_count = 0

channels.each do |channel|
  # Create analytics for last 30 days
  30.times do |i|
    date = i.days.ago.to_date
    
    ChannelAnalytics.create!(
      sales_channel: channel,
      date: date,
      orders_count: rand(10..100),
      revenue: rand(1000..10000),
      average_order_value: rand(50..200),
      unique_customers: rand(5..50),
      new_customers: rand(1..10),
      returning_customers: rand(4..40),
      conversion_rate: rand(1.0..5.0).round(2),
      return_rate: rand(0.5..3.0).round(2),
      units_sold: rand(20..200)
    )
    analytics_count += 1
  end
end

puts "    ✅ Created #{analytics_count} analytics records"

# Summary
puts ""
puts "✅ Omnichannel Integration seeding complete!"
puts ""
puts "Summary:"
puts "  - Sales Channels: #{SalesChannel.count}"
puts "  - Channel Products: #{ChannelProduct.count}"
puts "  - Channel Inventories: #{ChannelInventory.count}"
puts "  - Omnichannel Customers: #{OmnichannelCustomer.count}"
puts "  - Channel Interactions: #{ChannelInteraction.count}"
puts "  - Channel Preferences: #{ChannelPreference.count}"
puts "  - Cross-Channel Journeys: #{CrossChannelJourney.count}"
puts "  - Journey Touchpoints: #{JourneyTouchpoint.count}"
puts "  - Channel Integrations: #{ChannelIntegration.count}"
puts "  - Channel Analytics: #{ChannelAnalytics.count}"
puts ""
puts "Channels Created:"
SalesChannel.all.each do |channel|
  puts "  - #{channel.name} (#{channel.channel_type}): #{channel.status}"
end
puts ""

