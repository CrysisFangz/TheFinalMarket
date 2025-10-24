class LocalBusinessPresenter
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'local_business_presenter'
  CACHE_TTL = 10.minutes

  def initialize(business)
    @business = business
  end

  def as_json(options = {})
    cache_key = "#{CACHE_KEY_PREFIX}:json:#{@business.id}:#{options.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_presenter') do
        with_retry do
          {
            id: @business.id,
            business_name: @business.business_name,
            description: @business.description,
            city: @business.city,
            state: @business.state,
            zip_code: @business.zip_code,
            category: @business.category,
            verified: @business.verified?,
            verified_at: @business.verified_at,
            seller_id: @business.seller_id,
            seller_name: @business.seller&.name,
            badge: local_badge,
            analytics: business_analytics,
            location_data: location_data,
            contact_info: contact_info,
            business_hours: business_hours,
            created_at: @business.created_at,
            updated_at: @business.updated_at
          }.merge(options)
        end
      end
    end
  end

  def to_api_response
    cache_key = "#{CACHE_KEY_PREFIX}:api_response:#{@business.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_presenter') do
        with_retry do
          {
            success: true,
            data: as_json,
            metadata: {
              presented_at: Time.current,
              cache_used: false,
              version: '1.0'
            }
          }
        end
      end
    end
  end

  def to_search_result
    cache_key = "#{CACHE_KEY_PREFIX}:search_result:#{@business.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_presenter') do
        with_retry do
          {
            id: @business.id,
            business_name: @business.business_name,
            city: @business.city,
            state: @business.state,
            category: @business.category,
            verified: @business.verified?,
            badge: local_badge,
            rating: @business.average_rating || 0,
            review_count: @business.reviews_count || 0,
            distance: @business.distance_from_search || nil,
            popularity_score: calculate_popularity_score,
            search_relevance_score: @business.search_relevance_score || 0
          }
        end
      end
    end
  end

  def to_location_result(latitude, longitude)
    cache_key = "#{CACHE_KEY_PREFIX}:location_result:#{@business.id}:#{latitude}:#{longitude}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_presenter') do
        with_retry do
          distance = LocalBusinessLocationService.calculate_distance(
            latitude, longitude,
            @business.latitude || 0,
            @business.longitude || 0
          )

          to_search_result.merge(
            distance: distance,
            distance_unit: 'km',
            coordinates: {
              latitude: @business.latitude,
              longitude: @business.longitude
            }
          )
        end
      end
    end
  end

  def to_dashboard_data
    cache_key = "#{CACHE_KEY_PREFIX}:dashboard:#{@business.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_presenter') do
        with_retry do
          {
            business_info: {
              id: @business.id,
              name: @business.business_name,
              category: @business.category,
              location: "#{@business.city}, #{@business.state}",
              verified: @business.verified?,
              verified_at: @business.verified_at
            },
            performance_metrics: business_analytics,
            location_insights: location_insights,
            recommendations: generate_recommendations,
            alerts: generate_alerts,
            last_updated: Time.current
          }
        end
      end
    end
  end

  def to_export_data(format = :json)
    cache_key = "#{CACHE_KEY_PREFIX}:export:#{@business.id}:#{format}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('local_business_presenter') do
        with_retry do
          data = as_json(include_all: true)

          case format.to_sym
          when :csv
            convert_to_csv(data)
          when :xml
            convert_to_xml(data)
          else
            data
          end
        end
      end
    end
  end

  private

  def local_badge
    LocalBusinessManagementService.get_business_badge(@business)
  end

  def business_analytics
    LocalBusinessManagementService.get_business_analytics(@business)
  end

  def location_data
    {
      full_address: full_address,
      coordinates: {
        latitude: @business.latitude,
        longitude: @business.longitude
      },
      region: determine_region,
      timezone: determine_timezone
    }
  end

  def contact_info
    {
      phone: @business.phone,
      email: @business.email,
      website: @business.website,
      social_media: {
        facebook: @business.facebook_url,
        instagram: @business.instagram_url,
        twitter: @business.twitter_url
      }
    }
  end

  def business_hours
    return {} unless @business.business_hours.present?

    @business.business_hours
  end

  def location_insights
    {
      nearby_businesses_count: nearby_businesses_count,
      city_rank: city_rank,
      state_rank: state_rank,
      competitive_analysis: competitive_analysis
    }
  end

  def generate_recommendations
    recommendations = []

    unless @business.verified?
      recommendations << {
        type: 'verification',
        priority: 'high',
        title: 'Get Verified',
        description: 'Verification increases customer trust and visibility',
        action_url: "/businesses/#{@business.id}/verify"
      }
    end

    if (@business.average_rating || 0) < 3.5
      recommendations << {
        type: 'rating',
        priority: 'medium',
        title: 'Improve Customer Ratings',
        description: 'Focus on customer service to improve ratings',
        action_url: "/businesses/#{@business.id}/reviews"
      }
    end

    if (@business.views_count || 0) < 100
      recommendations << {
        type: 'visibility',
        priority: 'medium',
        title: 'Increase Visibility',
        description: 'Add photos and complete your business profile',
        action_url: "/businesses/#{@business.id}/edit"
      }
    end

    recommendations
  end

  def generate_alerts
    alerts = []

    if @business.verified_at.present? && @business.verified_at < 1.year.ago
      alerts << {
        type: 'renewal',
        priority: 'low',
        title: 'Verification Renewal Due',
        description: 'Your business verification needs renewal',
        action_url: "/businesses/#{@business.id}/renew_verification"
      }
    end

    if (@business.average_rating || 0) < 2.0
      alerts << {
        type: 'rating',
        priority: 'high',
        title: 'Low Rating Alert',
        description: 'Your business has low customer ratings',
        action_url: "/businesses/#{@business.id}/reviews"
      }
    end

    alerts
  end

  def full_address
    address_parts = [@business.address, @business.city, @business.state, @business.zip_code].compact
    address_parts.join(', ')
  end

  def determine_region
    LocalBusinessLocationService.determine_region(@business.state)
  end

  def determine_timezone
    # This would integrate with timezone service
    # For now, return default
    'America/New_York'
  end

  def nearby_businesses_count
    LocalBusinessLocationService.get_businesses_in_area(
      @business.latitude || 0,
      @business.longitude || 0,
      5
    ).count - 1 # Exclude self
  end

  def city_rank
    # Calculate rank within city based on ratings and verification
    city_businesses = LocalBusinessLocationService.get_businesses_in_city(@business.city)
    sorted_businesses = city_businesses.sort_by do |b|
      score = 0
      score += 50 if b.verified?
      score += (b.average_rating || 0) * 10
      score += [b.views_count || 0, 100].min
      -score # Negative for descending sort
    end

    sorted_businesses.index(@business) + 1
  end

  def state_rank
    # Calculate rank within state
    state_businesses = LocalBusinessLocationService.get_businesses_in_state(@business.state)
    sorted_businesses = state_businesses.sort_by do |b|
      score = 0
      score += 50 if b.verified?
      score += (b.average_rating || 0) * 10
      score += [b.views_count || 0, 100].min
      -score
    end

    sorted_businesses.index(@business) + 1
  end

  def competitive_analysis
    nearby_businesses = LocalBusinessLocationService.get_businesses_in_area(
      @business.latitude || 0,
      @business.longitude || 0,
      10
    )

    {
      nearby_competitors: nearby_businesses.count - 1,
      average_competitor_rating: calculate_average_competitor_rating(nearby_businesses),
      market_saturation: calculate_market_saturation(nearby_businesses)
    }
  end

  def calculate_popularity_score
    score = 0
    score += 50 if @business.verified?
    score += (@business.average_rating || 0) * 10
    score += [(@business.views_count || 0) / 10, 50].min
    score += [(@business.interactions_count || 0) / 5, 30].min
    [score, 100].min
  end

  def calculate_average_competitor_rating(nearby_businesses)
    ratings = nearby_businesses.reject { |b| b.id == @business.id }
                               .map(&:average_rating)
                               .compact

    ratings.any? ? (ratings.sum / ratings.size) : 0
  end

  def calculate_market_saturation(nearby_businesses)
    competitors = nearby_businesses.count - 1
    case competitors
    when 0..2
      'low'
    when 3..7
      'medium'
    when 8..15
      'high'
    else
      'very_high'
    end
  end

  def convert_to_csv(data)
    # Convert hash to CSV format
    CSV.generate do |csv|
      csv << data.keys
      csv << data.values
    end
  end

  def convert_to_xml(data)
    data.to_xml(root: 'business', skip_types: true)
  end
end