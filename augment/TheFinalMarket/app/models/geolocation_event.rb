class GeolocationEvent < ApplicationRecord
  belongs_to :user
  belongs_to :mobile_device, optional: true
  belongs_to :store_location, optional: true
  
  validates :user, presence: true
  validates :latitude, presence: true
  validates :longitude, presence: true
  validates :event_type, presence: true
  
  enum event_type: {
    check_in: 0,
    product_search: 1,
    store_visit: 2,
    delivery_tracking: 3,
    nearby_search: 4,
    geofence_enter: 5,
    geofence_exit: 6
  }
  
  # Scopes
  scope :recent, -> { where('recorded_at > ?', 24.hours.ago) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_type, ->(type) { where(event_type: type) }
  
  # Record geolocation event
  def self.record_event(user, event_type, latitude, longitude, device: nil, metadata: {})
    event = create!(
      user: user,
      mobile_device: device,
      event_type: event_type,
      latitude: latitude,
      longitude: longitude,
      accuracy: metadata[:accuracy],
      altitude: metadata[:altitude],
      speed: metadata[:speed],
      heading: metadata[:heading],
      recorded_at: Time.current,
      event_data: metadata
    )
    
    # Check for nearby stores
    nearby_stores = find_nearby_stores(latitude, longitude)
    if nearby_stores.any?
      event.update!(store_location: nearby_stores.first)
    end
    
    event
  end
  
  # Find nearby stores
  def self.find_nearby_stores(latitude, longitude, radius_km = 5)
    # Haversine formula to find nearby stores
    # This is a simplified version - in production use PostGIS or similar
    StoreLocation.where(
      "ST_DWithin(
        ST_MakePoint(?, ?),
        ST_MakePoint(longitude, latitude),
        ?
      )",
      longitude, latitude, radius_km * 1000
    )
  end
  
  # Get distance to a point
  def distance_to(lat, lng)
    # Haversine formula
    rad_per_deg = Math::PI / 180
    rkm = 6371 # Earth radius in kilometers
    
    dlat_rad = (lat - latitude) * rad_per_deg
    dlon_rad = (lng - longitude) * rad_per_deg
    
    lat1_rad = latitude * rad_per_deg
    lat2_rad = lat * rad_per_deg
    
    a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    
    rkm * c
  end
  
  # Get user's location history
  def self.user_history(user, limit: 50)
    where(user: user)
      .order(recorded_at: :desc)
      .limit(limit)
  end
  
  # Get popular locations
  def self.popular_locations(limit: 10)
    select('latitude, longitude, COUNT(*) as visit_count')
      .where('recorded_at > ?', 30.days.ago)
      .group('latitude, longitude')
      .order('visit_count DESC')
      .limit(limit)
  end
end

