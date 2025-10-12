class StoreLocation < ApplicationRecord
  has_many :geolocation_events
  has_many :store_visits
  
  validates :name, presence: true
  validates :latitude, presence: true
  validates :longitude, presence: true
  
  enum store_type: {
    retail: 0,
    warehouse: 1,
    pickup_point: 2,
    partner_store: 3
  }
  
  enum status: {
    active: 0,
    temporarily_closed: 1,
    permanently_closed: 2
  }
  
  # Scopes
  scope :active_stores, -> { where(status: :active) }
  scope :by_type, ->(type) { where(store_type: type) }
  
  # Find nearby stores
  def self.nearby(latitude, longitude, radius_km = 10)
    # Simplified distance calculation
    # In production, use PostGIS or similar
    all.select do |store|
      store.distance_to(latitude, longitude) <= radius_km
    end.sort_by { |store| store.distance_to(latitude, longitude) }
  end
  
  # Calculate distance to coordinates
  def distance_to(lat, lng)
    rad_per_deg = Math::PI / 180
    rkm = 6371
    
    dlat_rad = (lat - latitude) * rad_per_deg
    dlon_rad = (lng - longitude) * rad_per_deg
    
    lat1_rad = latitude * rad_per_deg
    lat2_rad = lat * rad_per_deg
    
    a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    
    rkm * c
  end
  
  # Get store details
  def details
    {
      name: name,
      address: address,
      city: city,
      state: state,
      zip_code: zip_code,
      phone: phone,
      store_type: store_type,
      status: status,
      hours: operating_hours,
      coordinates: { latitude: latitude, longitude: longitude }
    }
  end
  
  # Check if store is open now
  def open_now?
    return false unless active?
    return false unless operating_hours.present?
    
    now = Time.current
    day = now.strftime('%A').downcase
    hours = operating_hours[day]
    
    return false unless hours
    
    current_time = now.strftime('%H:%M')
    current_time >= hours['open'] && current_time <= hours['close']
  end
end

