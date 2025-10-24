class GeolocationEventPresenter
  def initialize(event)
    @event = event
  end

  def as_json(options = {})
    {
      id: @event.id,
      user_id: @event.user_id,
      mobile_device_id: @event.mobile_device_id,
      store_location_id: @event.store_location_id,
      event_type: @event.event_type,
      latitude: @event.latitude,
      longitude: @event.longitude,
      accuracy: @event.accuracy,
      altitude: @event.altitude,
      speed: @event.speed,
      heading: @event.heading,
      recorded_at: @event.recorded_at,
      event_data: @event.event_data,
      created_at: @event.created_at,
      updated_at: @event.updated_at
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end