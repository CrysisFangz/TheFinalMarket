class GeolocationService
  def self.record_event(user, event_type, latitude, longitude, device: nil, metadata: {})
    event = GeolocationEvent.create!(
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

  def self.find_nearby_stores(latitude, longitude, radius_km = 5)
    Rails.cache.fetch("nearby_stores:#{latitude}:#{longitude}:#{radius_km}", expires_in: 1.hour) do
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
  end

  def self.calculate_distance(lat1, lng1, lat2, lng2)
    Rails.cache.fetch("distance:#{lat1}:#{lng1}:#{lat2}:#{lng2}", expires_in: 1.hour) do
      # Haversine formula
      rad_per_deg = Math::PI / 180
      rkm = 6371 # Earth radius in kilometers

      dlat_rad = (lat2 - lat1) * rad_per_deg
      dlon_rad = (lng2 - lng1) * rad_per_deg

      lat1_rad = lat1 * rad_per_deg
      lat2_rad = lat2 * rad_per_deg

      a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2
      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

      rkm * c
    end
  end

  def self.get_user_history(user, limit: 50)
    Rails.cache.fetch("user:#{user.id}:location_history:#{limit}", expires_in: 30.minutes) do
      GeolocationEvent.where(user: user)
                     .order(recorded_at: :desc)
                     .limit(limit)
    end
  end

  def self.get_popular_locations(limit: 10)
    Rails.cache.fetch("popular_locations:#{limit}", expires_in: 1.hour) do
      GeolocationEvent.select('latitude, longitude, COUNT(*) as visit_count')
                     .where('recorded_at > ?', 30.days.ago)
                     .group('latitude, longitude')
                     .order('visit_count DESC')
                     .limit(limit)
    end
  end
end