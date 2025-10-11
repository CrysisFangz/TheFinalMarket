# db/seeds/mobile_app_seeds.rb
puts "🚀 Seeding Mobile App data..."

# Create sample stores for geolocation features
puts "Creating stores..."

stores_data = [
  {
    name: "Downtown Electronics",
    address: "123 Main St, San Francisco, CA 94102",
    latitude: 37.7749,
    longitude: -122.4194,
    phone: "(415) 555-0100",
    email: "info@downtownelectronics.com",
    description: "Your one-stop shop for all electronics",
    rating: 4.5,
    review_count: 250,
    hours: {
      monday: "9:00 AM - 9:00 PM",
      tuesday: "9:00 AM - 9:00 PM",
      wednesday: "9:00 AM - 9:00 PM",
      thursday: "9:00 AM - 9:00 PM",
      friday: "9:00 AM - 10:00 PM",
      saturday: "10:00 AM - 10:00 PM",
      sunday: "11:00 AM - 7:00 PM"
    }
  },
  {
    name: "Fashion District Boutique",
    address: "456 Market St, San Francisco, CA 94103",
    latitude: 37.7849,
    longitude: -122.4094,
    phone: "(415) 555-0200",
    email: "hello@fashiondistrict.com",
    description: "Trendy fashion and accessories",
    rating: 4.7,
    review_count: 180,
    hours: {
      monday: "10:00 AM - 8:00 PM",
      tuesday: "10:00 AM - 8:00 PM",
      wednesday: "10:00 AM - 8:00 PM",
      thursday: "10:00 AM - 8:00 PM",
      friday: "10:00 AM - 9:00 PM",
      saturday: "10:00 AM - 9:00 PM",
      sunday: "12:00 PM - 6:00 PM"
    }
  },
  {
    name: "Home & Garden Center",
    address: "789 Oak St, San Francisco, CA 94117",
    latitude: 37.7749,
    longitude: -122.4294,
    phone: "(415) 555-0300",
    email: "contact@homeandgarden.com",
    description: "Everything for your home and garden",
    rating: 4.3,
    review_count: 320,
    hours: {
      monday: "8:00 AM - 8:00 PM",
      tuesday: "8:00 AM - 8:00 PM",
      wednesday: "8:00 AM - 8:00 PM",
      thursday: "8:00 AM - 8:00 PM",
      friday: "8:00 AM - 9:00 PM",
      saturday: "8:00 AM - 9:00 PM",
      sunday: "9:00 AM - 7:00 PM"
    }
  },
  {
    name: "Sports & Outdoors",
    address: "321 Valencia St, San Francisco, CA 94110",
    latitude: 37.7649,
    longitude: -122.4214,
    phone: "(415) 555-0400",
    email: "info@sportsoutdoors.com",
    description: "Gear up for your next adventure",
    rating: 4.6,
    review_count: 210,
    hours: {
      monday: "9:00 AM - 8:00 PM",
      tuesday: "9:00 AM - 8:00 PM",
      wednesday: "9:00 AM - 8:00 PM",
      thursday: "9:00 AM - 8:00 PM",
      friday: "9:00 AM - 9:00 PM",
      saturday: "9:00 AM - 9:00 PM",
      sunday: "10:00 AM - 6:00 PM"
    }
  },
  {
    name: "Books & More",
    address: "654 Haight St, San Francisco, CA 94117",
    latitude: 37.7699,
    longitude: -122.4394,
    phone: "(415) 555-0500",
    email: "hello@booksandmore.com",
    description: "Independent bookstore with cafe",
    rating: 4.8,
    review_count: 450,
    hours: {
      monday: "10:00 AM - 9:00 PM",
      tuesday: "10:00 AM - 9:00 PM",
      wednesday: "10:00 AM - 9:00 PM",
      thursday: "10:00 AM - 9:00 PM",
      friday: "10:00 AM - 10:00 PM",
      saturday: "10:00 AM - 10:00 PM",
      sunday: "11:00 AM - 8:00 PM"
    }
  }
]

stores = stores_data.map do |store_data|
  Store.create!(store_data)
end

puts "✅ Created #{stores.count} stores"

# Create sample deals
puts "Creating local deals..."

deals_data = [
  {
    store: stores[0],
    title: "20% Off All Laptops",
    description: "Get 20% off on all laptop models this week only!",
    discount_percentage: 20.0,
    original_price: 999.99,
    deal_price: 799.99,
    starts_at: Time.current,
    expires_at: 7.days.from_now,
    active: true,
    redemption_limit: 50
  },
  {
    store: stores[1],
    title: "Buy One Get One 50% Off",
    description: "Buy any item and get the second one at 50% off",
    discount_percentage: 50.0,
    starts_at: Time.current,
    expires_at: 14.days.from_now,
    active: true,
    redemption_limit: 100
  },
  {
    store: stores[2],
    title: "Spring Garden Sale",
    description: "Up to 30% off on all garden supplies",
    discount_percentage: 30.0,
    starts_at: Time.current,
    expires_at: 30.days.from_now,
    active: true,
    redemption_limit: 200
  },
  {
    store: stores[3],
    title: "Outdoor Gear Clearance",
    description: "Clearance sale on last season's outdoor gear",
    discount_percentage: 40.0,
    starts_at: Time.current,
    expires_at: 21.days.from_now,
    active: true,
    redemption_limit: 75
  },
  {
    store: stores[4],
    title: "Book Club Special",
    description: "Join our book club and get 15% off all purchases",
    discount_percentage: 15.0,
    starts_at: Time.current,
    expires_at: 60.days.from_now,
    active: true,
    redemption_limit: 150
  }
]

deals = deals_data.map do |deal_data|
  Deal.create!(deal_data)
end

puts "✅ Created #{deals.count} deals"

# Add barcodes to existing products
puts "Adding barcodes to products..."

if Product.any?
  products_to_update = Product.limit(20)
  
  products_to_update.each_with_index do |product, index|
    # Generate realistic UPC-A barcode (12 digits)
    barcode = "04#{rand(10)}#{rand(10)}#{rand(10)}#{rand(10)}#{rand(10)}#{rand(10)}#{rand(10)}#{rand(10)}#{rand(10)}#{rand(10)}"
    
    # Assign random color
    colors = ['red', 'blue', 'green', 'black', 'white', 'gray', 'yellow', 'orange', 'purple', 'pink']
    
    product.update(
      barcode: barcode,
      primary_color: colors.sample
    )
  end
  
  puts "✅ Added barcodes to #{products_to_update.count} products"
else
  puts "⚠️  No products found. Skipping barcode assignment."
end

# Create sample product suggestions
puts "Creating product suggestions..."

suggestions_data = [
  {
    name: "Wireless Bluetooth Headphones",
    barcode: "042100005264",
    description: "Premium wireless headphones with noise cancellation",
    brand: "AudioTech",
    category: "Electronics",
    status: 0, # pending
    external_data: {
      source: "barcode_scan",
      confidence: 0.95
    }
  },
  {
    name: "Organic Green Tea",
    barcode: "041220576456",
    description: "100% organic green tea leaves",
    brand: "TeaTime",
    category: "Food & Beverage",
    status: 0,
    external_data: {
      source: "barcode_scan",
      confidence: 0.88
    }
  },
  {
    name: "Running Shoes - Men's",
    barcode: "045678901234",
    description: "Lightweight running shoes with cushioned sole",
    brand: "SportFit",
    category: "Sports & Outdoors",
    status: 0,
    external_data: {
      source: "barcode_scan",
      confidence: 0.92
    }
  }
]

suggestions = suggestions_data.map do |suggestion_data|
  ProductSuggestion.create!(suggestion_data)
end

puts "✅ Created #{suggestions.count} product suggestions"

# Create sample mobile devices for first user
if User.any?
  first_user = User.first
  
  puts "Creating sample mobile devices for #{first_user.email}..."
  
  devices_data = [
    {
      user: first_user,
      device_id: "iPhone-#{SecureRandom.hex(8)}",
      device_type: 0, # iOS
      device_name: "iPhone 14 Pro",
      os_version: "iOS 17.2",
      app_version: "1.0.0",
      status: 0, # active
      last_seen_at: Time.current,
      metadata: {
        biometric_available: true,
        ar_available: true,
        push_enabled: true
      }
    },
    {
      user: first_user,
      device_id: "Android-#{SecureRandom.hex(8)}",
      device_type: 1, # Android
      device_name: "Samsung Galaxy S23",
      os_version: "Android 14",
      app_version: "1.0.0",
      status: 0,
      last_seen_at: 2.days.ago,
      metadata: {
        biometric_available: true,
        ar_available: true,
        push_enabled: true
      }
    }
  ]
  
  devices = devices_data.map do |device_data|
    MobileDevice.create!(device_data)
  end
  
  puts "✅ Created #{devices.count} mobile devices"
  
  # Create sample barcode scans
  puts "Creating sample barcode scans..."
  
  if Product.where.not(barcode: nil).any?
    products_with_barcodes = Product.where.not(barcode: nil).limit(5)
    
    scans = products_with_barcodes.map do |product|
      BarcodeScan.create!(
        user: first_user,
        product: product,
        barcode: product.barcode,
        product_name: product.name,
        scanned_at: rand(1..30).days.ago,
        metadata: {
          location: "Downtown Electronics",
          device: "iPhone 14 Pro"
        }
      )
    end
    
    puts "✅ Created #{scans.count} barcode scans"
  else
    puts "⚠️  No products with barcodes found. Skipping scan creation."
  end
else
  puts "⚠️  No users found. Skipping mobile device and scan creation."
end

puts ""
puts "🎉 Mobile App seeding complete!"
puts ""
puts "Summary:"
puts "- #{Store.count} stores"
puts "- #{Deal.count} deals"
puts "- #{Product.where.not(barcode: nil).count} products with barcodes"
puts "- #{ProductSuggestion.count} product suggestions"
puts "- #{MobileDevice.count} mobile devices"
puts "- #{BarcodeScan.count} barcode scans"
puts ""
puts "Next steps:"
puts "1. Test barcode scanner at /mobile/scanner"
puts "2. Test visual search at /mobile/camera"
puts "3. Test geolocation at /mobile/nearby"
puts "4. Enable HTTPS for full mobile features"
puts ""

