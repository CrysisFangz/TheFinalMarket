class LocalBusinessLocationService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'local_business_location'
  CACHE_TTL = 30.minutes

  def self.get_businesses_in_city(city)
    cache_key = "#{CACHE_KEY_PREFIX}:city:#{city.downcase}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_location') do
        with_retry do
          businesses = LocalBusiness.in_city(city).includes(:seller).order(created_at: :desc).to_a

          EventPublisher.publish('local_business.location_searched', {
            location_type: 'city',
            location_value: city,
            results_count: businesses.count,
            searched_at: Time.current
          })

          businesses
        end
      end
    end
  end

  def self.get_businesses_in_state(state)
    cache_key = "#{CACHE_KEY_PREFIX}:state:#{state.downcase}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_location') do
        with_retry do
          businesses = LocalBusiness.in_state(state).includes(:seller).order(created_at: :desc).to_a

          EventPublisher.publish('local_business.location_searched', {
            location_type: 'state',
            location_value: state,
            results_count: businesses.count,
            searched_at: Time.current
          })

          businesses
        end
      end
    end
  end

  def self.get_businesses_in_area(latitude, longitude, radius_km = 25)
    cache_key = "#{CACHE_KEY_PREFIX}:area:#{latitude}:#{longitude}:#{radius_km}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_location') do
        with_retry do
          businesses = LocalBusiness.all

          # Calculate distances and filter
          nearby_businesses = businesses.select do |business|
            distance = calculate_distance(latitude, longitude, business.latitude || 0, business.longitude || 0)
            distance <= radius_km
          end

          nearby_businesses = nearby_businesses.sort_by do |business|
            calculate_distance(latitude, longitude, business.latitude || 0, business.longitude || 0)
          end

          EventPublisher.publish('local_business.area_searched', {
            latitude: latitude,
            longitude: longitude,
            radius_km: radius_km,
            results_count: nearby_businesses.count,
            searched_at: Time.current
          })

          nearby_businesses
        end
      end
    end
  end

  def self.get_businesses_by_coordinates(latitude, longitude)
    cache_key = "#{CACHE_KEY_PREFIX}:coordinates:#{latitude}:#{longitude}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_location') do
        with_retry do
          # Find businesses with exact coordinates
          businesses = LocalBusiness.where(latitude: latitude, longitude: longitude).includes(:seller).to_a

          EventPublisher.publish('local_business.coordinates_searched', {
            latitude: latitude,
            longitude: longitude,
            results_count: businesses.count,
            searched_at: Time.current
          })

          businesses
        end
      end
    end
  end

  def self.get_location_stats
    cache_key = "#{CACHE_KEY_PREFIX}:location_stats"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_location') do
        with_retry do
          businesses = LocalBusiness.all

          stats = {
            total_locations: businesses.count,
            unique_cities: businesses.distinct.pluck(:city).count,
            unique_states: businesses.distinct.pluck(:state).count,
            cities_with_businesses: businesses.group(:city).count,
            states_with_businesses: businesses.group(:state).count,
            top_cities: businesses.group(:city).count.sort_by { |_, count| -count }.first(20).to_h,
            top_states: businesses.group(:state).count.sort_by { |_, count| -count }.first(20).to_h,
            average_businesses_per_city: businesses.count.to_f / [businesses.distinct.pluck(:city).count, 1].max,
            average_businesses_per_state: businesses.count.to_f / [businesses.distinct.pluck(:state).count, 1].max,
            location_distribution: calculate_location_distribution(businesses)
          }

          EventPublisher.publish('local_business.location_stats_generated', {
            total_locations: stats[:total_locations],
            unique_cities: stats[:unique_cities],
            unique_states: stats[:unique_states],
            top_cities_count: stats[:top_cities].count,
            generated_at: Time.current
          })

          stats
        end
      end
    end
  end

  def self.find_businesses_near_address(address)
    cache_key = "#{CACHE_KEY_PREFIX}:address:#{address.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_location') do
        with_retry do
          # This would integrate with geocoding service in production
          # For now, return empty array as placeholder
          coordinates = geocode_address(address)

          if coordinates
            businesses = get_businesses_in_area(coordinates[:latitude], coordinates[:longitude], 10)
          else
            businesses = []
          end

          EventPublisher.publish('local_business.address_searched', {
            address: address,
            coordinates_found: coordinates.present?,
            results_count: businesses.count,
            searched_at: Time.current
          })

          businesses
        end
      end
    end
  end

  def self.get_businesses_in_bounding_box(north, south, east, west)
    cache_key = "#{CACHE_KEY_PREFIX}:bounding_box:#{north}:#{south}:#{east}:#{west}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_location') do
        with_retry do
          businesses = LocalBusiness.where(
            'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
            south, north, west, east
          ).includes(:seller).to_a

          EventPublisher.publish('local_business.bounding_box_searched', {
            north: north,
            south: south,
            east: east,
            west: west,
            results_count: businesses.count,
            searched_at: Time.current
          })

          businesses
        end
      end
    end
  end

  def self.get_businesses_by_zip_code(zip_code)
    cache_key = "#{CACHE_KEY_PREFIX}:zip_code:#{zip_code}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_location') do
        with_retry do
          # This would integrate with zip code to coordinates service
          # For now, return businesses with matching zip code if column exists
          if LocalBusiness.column_names.include?('zip_code')
            businesses = LocalBusiness.where(zip_code: zip_code).includes(:seller).to_a
          else
            businesses = []
          end

          EventPublisher.publish('local_business.zip_code_searched', {
            zip_code: zip_code,
            results_count: businesses.count,
            searched_at: Time.current
          })

          businesses
        end
      end
    end
  end

  def self.get_location_analytics(location_type, location_value)
    cache_key = "#{CACHE_KEY_PREFIX}:analytics:#{location_type}:#{location_value}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_location') do
        with_retry do
          case location_type.to_s.downcase
          when 'city'
            businesses = LocalBusiness.in_city(location_value)
          when 'state'
            businesses = LocalBusiness.in_state(location_value)
          else
            businesses = LocalBusiness.none
          end

          analytics = {
            total_businesses: businesses.count,
            verified_businesses: businesses.where(verified: true).count,
            average_rating: businesses.average(:average_rating) || 0,
            total_views: businesses.sum(:views_count) || 0,
            total_interactions: businesses.sum(:interactions_count) || 0,
            categories: businesses.group(:category).count,
            verification_rate: businesses.any? ? (businesses.where(verified: true).count.to_f / businesses.count) * 100 : 0,
            engagement_metrics: calculate_engagement_metrics(businesses)
          }

          EventPublisher.publish('local_business.location_analytics_generated', {
            location_type: location_type,
            location_value: location_value,
            total_businesses: analytics[:total_businesses],
            average_rating: analytics[:average_rating],
            generated_at: Time.current
          })

          analytics
        end
      end
    end
  end

  def self.get_popular_locations(limit = 20)
    cache_key = "#{CACHE_KEY_PREFIX}:popular_locations:#{limit}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_location') do
        with_retry do
          businesses = LocalBusiness.all

          # Calculate popularity based on business count, verification rate, and ratings
          city_popularity = businesses.group(:city).count.map do |city, count|
            city_businesses = businesses.where(city: city)
            verified_count = city_businesses.where(verified: true).count
            avg_rating = city_businesses.average(:average_rating) || 0

            popularity_score = (count * 10) + (verified_count * 20) + (avg_rating * 5)

            {
              city: city,
              state: city_businesses.first&.state,
              business_count: count,
              verified_count: verified_count,
              average_rating: avg_rating,
              popularity_score: popularity_score
            }
          end

          popular_locations = city_popularity.sort_by { |loc| -loc[:popularity_score] }.first(limit)

          EventPublisher.publish('local_business.popular_locations_generated', {
            limit: limit,
            locations_count: popular_locations.count,
            generated_at: Time.current
          })

          popular_locations
        end
      end
    end
  end

  def self.validate_coordinates(latitude, longitude)
    cache_key = "#{CACHE_KEY_PREFIX}:validate_coordinates:#{latitude}:#{longitude}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_location') do
        with_retry do
          valid = latitude.is_a?(Numeric) && longitude.is_a?(Numeric) &&
                  latitude >= -90 && latitude <= 90 &&
                  longitude >= -180 && longitude <= 180

          {
            valid: valid,
            latitude: latitude,
            longitude: longitude,
            within_bounds: valid
          }
        end
      end
    end
  end

  private

  def self.calculate_distance(lat1, lon1, lat2, lon2)
    # Haversine formula for calculating distance between two points
    return 0 if lat1 == lat2 && lon1 == lon2

    radius = 6371 # Earth's radius in kilometers

    dlat = (lat2 - lat1) * Math::PI / 180
    dlon = (lon2 - lon1) * Math::PI / 180

    a = Math.sin(dlat / 2) * Math.sin(dlat / 2) +
        Math.cos(lat1 * Math::PI / 180) * Math.cos(lat2 * Math::PI / 180) *
        Math.sin(dlon / 2) * Math.sin(dlon / 2)

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    distance = radius * c

    distance
  end

  def self.geocode_address(address)
    # This would integrate with a geocoding service like Google Maps API
    # For now, return nil as placeholder
    nil
  end

  def self.calculate_location_distribution(businesses)
    distribution = {
      by_city: {},
      by_state: {},
      by_region: {}
    }

    businesses.each do |business|
      # City distribution
      distribution[:by_city][business.city] ||= 0
      distribution[:by_city][business.city] += 1

      # State distribution
      distribution[:by_state][business.state] ||= 0
      distribution[:by_state][business.state] += 1

      # Region distribution (simplified - would use actual regions in production)
      region = determine_region(business.state)
      distribution[:by_region][region] ||= 0
      distribution[:by_region][region] += 1
    end

    distribution
  end

  def self.determine_region(state)
    # Simplified region determination - would use actual regional data in production
    case state&.upcase
    when 'CA', 'OR', 'WA', 'NV', 'ID', 'MT', 'WY', 'CO', 'NM', 'AZ', 'UT'
      'West'
    when 'TX', 'OK', 'KS', 'NE', 'SD', 'ND', 'MN', 'IA', 'MO', 'AR', 'LA', 'WI', 'IL', 'IN', 'OH', 'MI'
      'Midwest'
    when 'NY', 'PA', 'NJ', 'CT', 'MA', 'VT', 'NH', 'ME', 'RI', 'DE', 'MD', 'VA', 'WV', 'KY', 'TN', 'NC', 'SC', 'GA', 'FL', 'AL', 'MS'
      'East'
    when 'AK', 'HI'
      'Pacific'
    else
      'Unknown'
    end
  end

  def self.calculate_engagement_metrics(businesses)
    return {} if businesses.empty?

    total_views = businesses.sum(:views_count) || 0
    total_interactions = businesses.sum(:interactions_count) || 0
    average_rating = businesses.average(:average_rating) || 0

    {
      total_views: total_views,
      total_interactions: total_interactions,
      average_rating: average_rating,
      conversion_rate: total_views > 0 ? (total_interactions.to_f / total_views) * 100 : 0,
      businesses_with_views: businesses.where('views_count > 0').count,
      businesses_with_interactions: businesses.where('interactions_count > 0').count,
      businesses_with_ratings: businesses.where('average_rating > 0').count
    }
  end
end