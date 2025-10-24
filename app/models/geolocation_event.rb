class GeolocationEvent < ApplicationRecord
  include CircuitBreaker
  include Retryable

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

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Record geolocation event
  def self.record_event(user, event_type, latitude, longitude, device: nil, metadata: {})
    GeolocationService.record_event(user, event_type, latitude, longitude, device: device, metadata: metadata)
  end

  # Find nearby stores
  def self.find_nearby_stores(latitude, longitude, radius_km = 5)
    GeolocationService.find_nearby_stores(latitude, longitude, radius_km)
  end

  # Get distance to a point
  def distance_to(lat, lng)
    GeolocationService.calculate_distance(latitude, longitude, lat, lng)
  end

  # Get user's location history
  def self.user_history(user, limit: 50)
    GeolocationService.get_user_history(user, limit: limit)
  end

  # Get popular locations
  def self.popular_locations(limit: 10)
    GeolocationService.get_popular_locations(limit: limit)
  end

  private

  def publish_created_event
    EventPublisher.publish('geolocation_event.created', {
      event_id: id,
      user_id: user_id,
      mobile_device_id: mobile_device_id,
      store_location_id: store_location_id,
      event_type: event_type,
      latitude: latitude,
      longitude: longitude,
      recorded_at: recorded_at,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('geolocation_event.updated', {
      event_id: id,
      user_id: user_id,
      mobile_device_id: mobile_device_id,
      store_location_id: store_location_id,
      event_type: event_type,
      latitude: latitude,
      longitude: longitude,
      recorded_at: recorded_at,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('geolocation_event.destroyed', {
      event_id: id,
      user_id: user_id,
      mobile_device_id: mobile_device_id,
      store_location_id: store_location_id,
      event_type: event_type,
      latitude: latitude,
      longitude: longitude
    })
  end
end