class LocalBusinessManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'local_business_management'
  CACHE_TTL = 15.minutes

  def self.verify_business(business)
    cache_key = "#{CACHE_KEY_PREFIX}:verify:#{business.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          if business.update!(verified: true, verified_at: Time.current)
            EventPublisher.publish('local_business.verified', {
              business_id: business.id,
              seller_id: business.seller_id,
              business_name: business.business_name,
              city: business.city,
              state: business.state,
              verified_at: business.verified_at
            })

            clear_business_cache(business.id)
            true
          else
            false
          end
        end
      end
    end
  end

  def self.create_business(seller, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:create:#{seller.id}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          business = LocalBusiness.new(
            seller: seller,
            **attributes
          )

          if business.save
            EventPublisher.publish('local_business.created', {
              business_id: business.id,
              seller_id: seller.id,
              business_name: business.business_name,
              city: business.city,
              state: business.state,
              created_at: business.created_at
            })

            business
          else
            false
          end
        end
      end
    end
  end

  def self.update_business(business, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:update:#{business.id}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          if business.update(attributes)
            EventPublisher.publish('local_business.updated', {
              business_id: business.id,
              seller_id: business.seller_id,
              business_name: business.business_name,
              city: business.city,
              state: business.state,
              updated_at: business.updated_at
            })

            clear_business_cache(business.id)
            true
          else
            false
          end
        end
      end
    end
  end

  def self.get_businesses_for_seller(seller_id)
    cache_key = "#{CACHE_KEY_PREFIX}:seller_businesses:#{seller_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          LocalBusiness.where(seller_id: seller_id).includes(:seller).order(created_at: :desc).to_a
        end
      end
    end
  end

  def self.get_verified_businesses
    cache_key = "#{CACHE_KEY_PREFIX}:verified_businesses"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          LocalBusiness.verified.includes(:seller).order(created_at: :desc).to_a
        end
      end
    end
  end

  def self.get_businesses_by_location(city, state)
    cache_key = "#{CACHE_KEY_PREFIX}:location_businesses:#{city}:#{state}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          LocalBusiness.where(city: city, state: state).includes(:seller).order(created_at: :desc).to_a
        end
      end
    end
  end

  def self.get_business_badge(business)
    cache_key = "#{CACHE_KEY_PREFIX}:badge:#{business.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          {
            icon: '🏪',
            text: "Local Business - #{business.city}, #{business.state}",
            verified: business.verified?,
            business_id: business.id,
            seller_id: business.seller_id
          }
        end
      end
    end
  end

  def self.get_business_stats
    cache_key = "#{CACHE_KEY_PREFIX}:stats"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          businesses = LocalBusiness.all

          stats = {
            total_businesses: businesses.count,
            verified_businesses: businesses.where(verified: true).count,
            unverified_businesses: businesses.where(verified: false).count,
            businesses_by_state: businesses.group(:state).count,
            businesses_by_city: businesses.group(:city).count,
            top_cities: businesses.group(:city).count.sort_by { |_, count| -count }.first(10).to_h,
            top_states: businesses.group(:state).count.sort_by { |_, count| -count }.first(10).to_h,
            verification_rate: businesses.any? ? (businesses.where(verified: true).count.to_f / businesses.count) * 100 : 0
          }

          EventPublisher.publish('local_business.stats_generated', {
            total_businesses: stats[:total_businesses],
            verified_businesses: stats[:verified_businesses],
            verification_rate: stats[:verification_rate],
            top_cities_count: stats[:top_cities].count,
            generated_at: Time.current
          })

          stats
        end
      end
    end
  end

  def self.search_businesses(query, filters = {})
    cache_key = "#{CACHE_KEY_PREFIX}:search:#{query}:#{filters.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          businesses = LocalBusiness.all

          # Apply text search
          if query.present?
            businesses = businesses.where('business_name ILIKE ? OR description ILIKE ? OR category ILIKE ?',
                                        "%#{query}%", "%#{query}%", "%#{query}%")
          end

          # Apply filters
          businesses = businesses.where(verified: filters[:verified]) if filters[:verified].present?
          businesses = businesses.where(state: filters[:state]) if filters[:state].present?
          businesses = businesses.where(city: filters[:city]) if filters[:city].present?
          businesses = businesses.where(category: filters[:category]) if filters[:category].present?

          # Apply sorting
          case filters[:sort_by]
          when 'name'
            businesses = businesses.order(:business_name)
          when 'city'
            businesses = businesses.order(:city)
          when 'newest'
            businesses = businesses.order(created_at: :desc)
          when 'oldest'
            businesses = businesses.order(created_at: :asc)
          else
            businesses = businesses.order(created_at: :desc)
          end

          businesses = businesses.includes(:seller).to_a

          EventPublisher.publish('local_business.search_performed', {
            query: query,
            filters: filters,
            results_count: businesses.count,
            searched_at: Time.current
          })

          businesses
        end
      end
    end
  end

  def self.get_nearby_businesses(latitude, longitude, radius_km = 10)
    cache_key = "#{CACHE_KEY_PREFIX}:nearby:#{latitude}:#{longitude}:#{radius_km}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          # This would integrate with geolocation service
          # For now, return businesses in same city/state
          businesses = LocalBusiness.all

          # Simple distance calculation (would use proper geolocation in production)
          nearby_businesses = businesses.select do |business|
            distance = calculate_distance(latitude, longitude, business.latitude || 0, business.longitude || 0)
            distance <= radius_km
          end

          EventPublisher.publish('local_business.nearby_searched', {
            latitude: latitude,
            longitude: longitude,
            radius_km: radius_km,
            nearby_count: nearby_businesses.count,
            searched_at: Time.current
          })

          nearby_businesses
        end
      end
    end
  end

  def self.get_business_analytics(business)
    cache_key = "#{CACHE_KEY_PREFIX}:analytics:#{business.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          analytics = {
            total_views: business.views_count || 0,
            total_interactions: business.interactions_count || 0,
            average_rating: business.average_rating || 0,
            total_reviews: business.reviews_count || 0,
            conversion_rate: calculate_conversion_rate(business),
            popularity_score: calculate_popularity_score(business),
            engagement_metrics: get_engagement_metrics(business)
          }

          EventPublisher.publish('local_business.analytics_generated', {
            business_id: business.id,
            seller_id: business.seller_id,
            total_views: analytics[:total_views],
            average_rating: analytics[:average_rating],
            generated_at: Time.current
          })

          analytics
        end
      end
    end
  end

  private

  def self.calculate_distance(lat1, lon1, lat2, lon2)
    # Simple distance calculation (Haversine formula would be used in production)
    Math.sqrt((lat2 - lat1) ** 2 + (lon2 - lon1) ** 2) * 111 # Rough km conversion
  end

  def self.calculate_conversion_rate(business)
    # Calculate conversion from views to interactions
    views = business.views_count || 1
    interactions = business.interactions_count || 0

    (interactions.to_f / views) * 100
  end

  def self.calculate_popularity_score(business)
    score = 0

    # Base score from verification
    score += 50 if business.verified?

    # Score from ratings
    score += (business.average_rating || 0) * 10

    # Score from activity
    score += [business.views_count || 0, 100].min
    score += [business.interactions_count || 0, 50].min

    [score, 100].min
  end

  def self.get_engagement_metrics(business)
    {
      views_per_day: (business.views_count || 0) / [business.days_active || 1, 1].max,
      interactions_per_view: calculate_conversion_rate(business),
      review_response_rate: business.review_response_rate || 0,
      customer_satisfaction: business.average_rating || 0
    }
  end

  def self.clear_business_cache(business_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:verify:#{business_id}",
      "#{CACHE_KEY_PREFIX}:update:#{business_id}",
      "#{CACHE_KEY_PREFIX}:badge:#{business_id}",
      "#{CACHE_KEY_PREFIX}:analytics:#{business_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end</content>
<content lines="1-150">
class LocalBusinessManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'local_business_management'
  CACHE_TTL = 15.minutes

  def self.verify_business(business)
    cache_key = "#{CACHE_KEY_PREFIX}:verify:#{business.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          if business.update!(verified: true, verified_at: Time.current)
            EventPublisher.publish('local_business.verified', {
              business_id: business.id,
              seller_id: business.seller_id,
              business_name: business.business_name,
              city: business.city,
              state: business.state,
              verified_at: business.verified_at
            })

            clear_business_cache(business.id)
            true
          else
            false
          end
        end
      end
    end
  end

  def self.create_business(seller, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:create:#{seller.id}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          business = LocalBusiness.new(
            seller: seller,
            **attributes
          )

          if business.save
            EventPublisher.publish('local_business.created', {
              business_id: business.id,
              seller_id: seller.id,
              business_name: business.business_name,
              city: business.city,
              state: business.state,
              created_at: business.created_at
            })

            business
          else
            false
          end
        end
      end
    end
  end

  def self.update_business(business, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:update:#{business.id}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          if business.update(attributes)
            EventPublisher.publish('local_business.updated', {
              business_id: business.id,
              seller_id: business.seller_id,
              business_name: business.business_name,
              city: business.city,
              state: business.state,
              updated_at: business.updated_at
            })

            clear_business_cache(business.id)
            true
          else
            false
          end
        end
      end
    end
  end

  def self.get_businesses_for_seller(seller_id)
    cache_key = "#{CACHE_KEY_PREFIX}:seller_businesses:#{seller_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          LocalBusiness.where(seller_id: seller_id).includes(:seller).order(created_at: :desc).to_a
        end
      end
    end
  end

  def self.get_verified_businesses
    cache_key = "#{CACHE_KEY_PREFIX}:verified_businesses"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          LocalBusiness.verified.includes(:seller).order(created_at: :desc).to_a
        end
      end
    end
  end

  def self.get_businesses_by_location(city, state)
    cache_key = "#{CACHE_KEY_PREFIX}:location_businesses:#{city}:#{state}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          LocalBusiness.where(city: city, state: state).includes(:seller).order(created_at: :desc).to_a
        end
      end
    end
  end

  def self.get_business_badge(business)
    cache_key = "#{CACHE_KEY_PREFIX}:badge:#{business.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          {
            icon: '🏪',
            text: "Local Business - #{business.city}, #{business.state}",
            verified: business.verified?,
            business_id: business.id,
            seller_id: business.seller_id
          }
        end
      end
    end
  end

  def self.get_business_stats
    cache_key = "#{CACHE_KEY_PREFIX}:stats"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          businesses = LocalBusiness.all

          stats = {
            total_businesses: businesses.count,
            verified_businesses: businesses.where(verified: true).count,
            unverified_businesses: businesses.where(verified: false).count,
            businesses_by_state: businesses.group(:state).count,
            businesses_by_city: businesses.group(:city).count,
            top_cities: businesses.group(:city).count.sort_by { |_, count| -count }.first(10).to_h,
            top_states: businesses.group(:state).count.sort_by { |_, count| -count }.first(10).to_h,
            verification_rate: businesses.any? ? (businesses.where(verified: true).count.to_f / businesses.count) * 100 : 0
          }

          EventPublisher.publish('local_business.stats_generated', {
            total_businesses: stats[:total_businesses],
            verified_businesses: stats[:verified_businesses],
            verification_rate: stats[:verification_rate],
            top_cities_count: stats[:top_cities].count,
            generated_at: Time.current
          })

          stats
        end
      end
    end
  end

  def self.search_businesses(query, filters = {})
    cache_key = "#{CACHE_KEY_PREFIX}:search:#{query}:#{filters.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          businesses = LocalBusiness.all

          # Apply text search
          if query.present?
            businesses = businesses.where('business_name ILIKE ? OR description ILIKE ? OR category ILIKE ?',
                                        "%#{query}%", "%#{query}%", "%#{query}%")
          end

          # Apply filters
          businesses = businesses.where(verified: filters[:verified]) if filters[:verified].present?
          businesses = businesses.where(state: filters[:state]) if filters[:state].present?
          businesses = businesses.where(city: filters[:city]) if filters[:city].present?
          businesses = businesses.where(category: filters[:category]) if filters[:category].present?

          # Apply sorting
          case filters[:sort_by]
          when 'name'
            businesses = businesses.order(:business_name)
          when 'city'
            businesses = businesses.order(:city)
          when 'newest'
            businesses = businesses.order(created_at: :desc)
          when 'oldest'
            businesses = businesses.order(created_at: :asc)
          else
            businesses = businesses.order(created_at: :desc)
          end

          businesses = businesses.includes(:seller).to_a

          EventPublisher.publish('local_business.search_performed', {
            query: query,
            filters: filters,
            results_count: businesses.count,
            searched_at: Time.current
          })

          businesses
        end
      end
    end
  end

  def self.get_nearby_businesses(latitude, longitude, radius_km = 10)
    cache_key = "#{CACHE_KEY_PREFIX}:nearby:#{latitude}:#{longitude}:#{radius_km}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          # This would integrate with geolocation service
          # For now, return businesses in same city/state
          businesses = LocalBusiness.all

          # Simple distance calculation (would use proper geolocation in production)
          nearby_businesses = businesses.select do |business|
            distance = calculate_distance(latitude, longitude, business.latitude || 0, business.longitude || 0)
            distance <= radius_km
          end

          EventPublisher.publish('local_business.nearby_searched', {
            latitude: latitude,
            longitude: longitude,
            radius_km: radius_km,
            nearby_count: nearby_businesses.count,
            searched_at: Time.current
          })

          nearby_businesses
        end
      end
    end
  end

  def self.get_business_analytics(business)
    cache_key = "#{CACHE_KEY_PREFIX}:analytics:#{business.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_management') do
        with_retry do
          analytics = {
            total_views: business.views_count || 0,
            total_interactions: business.interactions_count || 0,
            average_rating: business.average_rating || 0,
            total_reviews: business.reviews_count || 0,
            conversion_rate: calculate_conversion_rate(business),
            popularity_score: calculate_popularity_score(business),
            engagement_metrics: get_engagement_metrics(business)
          }

          EventPublisher.publish('local_business.analytics_generated', {
            business_id: business.id,
            seller_id: business.seller_id,
            total_views: analytics[:total_views],
            average_rating: analytics[:average_rating],
            generated_at: Time.current
          })

          analytics
        end
      end
    end
  end

  private

  def self.calculate_distance(lat1, lon1, lat2, lon2)
    # Simple distance calculation (Haversine formula would be used in production)
    Math.sqrt((lat2 - lat1) ** 2 + (lon2 - lon1) ** 2) * 111 # Rough km conversion
  end

  def self.calculate_conversion_rate(business)
    # Calculate conversion from views to interactions
    views = business.views_count || 1
    interactions = business.interactions_count || 0

    (interactions.to_f / views) * 100
  end

  def self.calculate_popularity_score(business)
    score = 0

    # Base score from verification
    score += 50 if business.verified?

    # Score from ratings
    score += (business.average_rating || 0) * 10

    # Score from activity
    score += [business.views_count || 0, 100].min
    score += [business.interactions_count || 0, 50].min

    [score, 100].min
  end

  def self.get_engagement_metrics(business)
    {
      views_per_day: (business.views_count || 0) / [business.days_active || 1, 1].max,
      interactions_per_view: calculate_conversion_rate(business),
      review_response_rate: business.review_response_rate || 0,
      customer_satisfaction: business.average_rating || 0
    }
  end

  def self.clear_business_cache(business_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:verify:#{business_id}",
      "#{CACHE_KEY_PREFIX}:update:#{business_id}",
      "#{CACHE_KEY_PREFIX}:badge:#{business_id}",
      "#{CACHE_KEY_PREFIX}:analytics:#{business_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end