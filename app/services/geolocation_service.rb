# frozen_string_literal: true

# Service for handling geolocation features
class GeolocationService
  EARTH_RADIUS_KM = 6371.0

  def initialize(latitude, longitude)
    @latitude = latitude.to_f
    @longitude = longitude.to_f
    validate_coordinates!
  end

  # Find nearby stores
  def nearby_stores(radius_km: 10, limit: 10)
    Store.where(
      "earth_distance(ll_to_earth(?, ?), ll_to_earth(latitude, longitude)) <= ?",
      @latitude, @longitude, radius_km * 1000
    )
    .select("*, earth_distance(ll_to_earth(#{@latitude}, #{@longitude}), ll_to_earth(latitude, longitude)) as distance")
    .order('distance')
    .limit(limit)
    .map do |store|
      {
        id: store.id,
        name: store.name,
        address: store.address,
        distance_km: (store.distance / 1000.0).round(2),
        latitude: store.latitude,
        longitude: store.longitude,
        phone: store.phone,
        hours: store.business_hours,
        is_open: store.open_now?
      }
    end
  end

  # Find local deals near user
  def local_deals(radius_km: 5)
    nearby_store_ids = nearby_stores(radius_km: radius_km).map { |s| s[:id] }
    
    Deal.active
        .where(store_id: nearby_store_ids)
        .includes(:product, :store)
        .order(discount_percentage: :desc)
        .limit(20)
        .map do |deal|
          {
            id: deal.id,
            product: deal.product.name,
            original_price: deal.product.price,
            deal_price: deal.discounted_price,
            discount: deal.discount_percentage,
            store: deal.store.name,
            distance_km: calculate_distance(deal.store.latitude, deal.store.longitude),
            expires_at: deal.expires_at,
            image: deal.product.images.first&.url
          }
        end
  end

  # Get delivery zones
  def delivery_available?
    DeliveryZone.where(
      "ST_Contains(boundary, ST_SetSRID(ST_MakePoint(?, ?), 4326))",
      @longitude, @latitude
    ).exists?
  end

  def delivery_info
    zone = DeliveryZone.where(
      "ST_Contains(boundary, ST_SetSRID(ST_MakePoint(?, ?), 4326))",
      @longitude, @latitude
    ).first

    return { available: false } unless zone

    {
      available: true,
      zone_name: zone.name,
      delivery_fee: zone.delivery_fee,
      minimum_order: zone.minimum_order,
      estimated_time: zone.estimated_delivery_time,
      free_delivery_threshold: zone.free_delivery_threshold
    }
  end

  # Find products available nearby
  def nearby_products(category: nil, limit: 50)
    nearby_store_ids = nearby_stores.map { |s| s[:id] }
    
    products = Product.joins(:store_inventories)
                     .where(store_inventories: { store_id: nearby_store_ids, quantity: 1.. })
                     .distinct

    products = products.where(category: category) if category
    
    products.limit(limit).map do |product|
      available_stores = product.store_inventories
                               .where(store_id: nearby_store_ids, quantity: 1..)
                               .includes(:store)
      
      {
        id: product.id,
        name: product.name,
        price: product.price,
        image: product.images.first&.url,
        available_at: available_stores.map do |inv|
          store = inv.store
          {
            store_name: store.name,
            distance_km: calculate_distance(store.latitude, store.longitude),
            stock: inv.quantity
          }
        end
      }
    end
  end

  # Get user's location context
  def location_context
    {
      coordinates: { latitude: @latitude, longitude: @longitude },
      nearby_stores_count: nearby_stores.count,
      delivery_available: delivery_available?,
      nearest_store: nearest_store,
      local_deals_count: local_deals.count,
      timezone: timezone,
      weather: weather_info
    }
  end

  # Calculate distance between two points
  def calculate_distance(lat2, lon2)
    lat1_rad = @latitude * Math::PI / 180
    lat2_rad = lat2 * Math::PI / 180
    delta_lat = (lat2 - @latitude) * Math::PI / 180
    delta_lon = (lon2 - @longitude) * Math::PI / 180

    a = Math.sin(delta_lat / 2) ** 2 +
        Math.cos(lat1_rad) * Math.cos(lat2_rad) *
        Math.sin(delta_lon / 2) ** 2
    
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    
    (EARTH_RADIUS_KM * c).round(2)
  end

  # Geocode address to coordinates
  def self.geocode_address(address)
    # Integration with geocoding service (Google Maps, Mapbox, etc.)
    # For now, return mock data
    
    {
      latitude: 40.7128,
      longitude: -74.0060,
      formatted_address: address,
      city: 'New York',
      state: 'NY',
      country: 'USA',
      postal_code: '10001'
    }
  end

  # Reverse geocode coordinates to address
  def reverse_geocode
    # Integration with reverse geocoding service
    
    {
      address: '123 Main St',
      city: 'New York',
      state: 'NY',
      country: 'USA',
      postal_code: '10001',
      formatted_address: '123 Main St, New York, NY 10001'
    }
  end

  private

  def validate_coordinates!
    unless @latitude.between?(-90, 90) && @longitude.between?(-180, 180)
      raise ArgumentError, "Invalid coordinates: #{@latitude}, #{@longitude}"
    end
  end

  def nearest_store
    stores = nearby_stores(limit: 1)
    stores.first
  end

  def timezone
    # Determine timezone based on coordinates
    # Integration with timezone API
    'America/New_York'
  end

  def weather_info
    # Integration with weather API
    {
      temperature: 72,
      condition: 'Sunny',
      humidity: 65
    }
  end
end

