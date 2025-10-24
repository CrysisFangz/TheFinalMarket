class LocalBusiness < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :seller, class_name: 'User'

  # Enhanced validations with business logic
  validates :business_name, presence: true, length: { maximum: 100 }
  validates :city, presence: true, length: { maximum: 50 }
  validates :state, presence: true, length: { maximum: 50 }
  validates :description, length: { maximum: 1000 }, allow_blank: true
  validates :category, presence: true, length: { maximum: 50 }
  validates :phone, format: { with: /\A[\+]?[0-9\s\-\(\)]+\z/ }, allow_blank: true
  validates :email, format: { with: /\A[^@\s]+@[^@\s]+\z/ }, allow_blank: true
  validates :website, format: { with: /\Ahttps?:\/\/.+/ }, allow_blank: true

  # Enhanced scopes with caching
  scope :verified, -> { where(verified: true) }
  scope :in_city, ->(city) { where(city: city) }
  scope :in_state, ->(state) { where(state: state) }
  scope :active, -> { where(active: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :recently_verified, -> { verified.where('verified_at >= ?', 30.days.ago) }
  scope :top_rated, -> { where('average_rating >= 4.0').order(average_rating: :desc) }

  # Enhanced attributes with defaults
  attribute :verified, :boolean, default: false
  attribute :active, :boolean, default: true
  attribute :average_rating, :decimal, default: 0.0
  attribute :views_count, :integer, default: 0
  attribute :interactions_count, :integer, default: 0
  attribute :reviews_count, :integer, default: 0

  # Event publishing callbacks
  after_create :publish_creation_event
  after_update :publish_update_event
  after_destroy :publish_deletion_event

  # Enhanced business methods using services
  def verify!
    with_circuit_breaker('local_business_verification') do
      with_retry do
        LocalBusinessManagementService.verify_business(self)
      end
    end
  end

  def local_badge
    LocalBusinessManagementService.get_business_badge(self)
  end

  def analytics
    LocalBusinessManagementService.get_business_analytics(self)
  end

  def nearby_businesses(radius_km = 10)
    if latitude.present? && longitude.present?
      LocalBusinessLocationService.get_businesses_in_area(latitude, longitude, radius_km)
    else
      []
    end
  end

  def update_analytics!(views: nil, interactions: nil, rating: nil)
    with_circuit_breaker('local_business_analytics') do
      with_retry do
        updates = {}
        updates[:views_count] = views if views.present?
        updates[:interactions_count] = interactions if interactions.present?
        updates[:average_rating] = rating if rating.present?
        updates[:reviews_count] = reviews.count if reviews_count_changed?

        update!(updates) if updates.any?
      end
    end
  end

  def full_address
    [address, city, state, zip_code].compact.join(', ')
  end

  def location_coordinates
    [latitude, longitude] if latitude.present? && longitude.present?
  end

  def is_verified?
    verified? && verified_at.present?
  end

  def needs_verification_renewal?
    verified_at.present? && verified_at < 1.year.ago
  end

  def popularity_score
    calculate_popularity_score
  end

  def engagement_rate
    return 0 if views_count.zero?
    (interactions_count.to_f / views_count) * 100
  end

  def city_rank
    city_businesses = LocalBusinessLocationService.get_businesses_in_city(city)
    sorted_businesses = city_businesses.sort_by { |b| -b.popularity_score }
    sorted_businesses.index(self) + 1
  end

  def state_rank
    state_businesses = LocalBusinessLocationService.get_businesses_in_state(state)
    sorted_businesses = state_businesses.sort_by { |b| -b.popularity_score }
    sorted_businesses.index(self) + 1
  end

  def competitive_position
    nearby = nearby_businesses(5)
    competitors = nearby.reject { |b| b.id == id }

    {
      nearby_competitors: competitors.count,
      average_competitor_rating: competitors.map(&:average_rating).compact.average,
      market_position: calculate_market_position(competitors)
    }
  end

  def to_presenter
    LocalBusinessPresenter.new(self)
  end

  def as_json(options = {})
    to_presenter.as_json(options)
  end

  def to_api_response
    to_presenter.to_api_response
  end

  def to_search_result
    to_presenter.to_search_result
  end

  def to_location_result(latitude, longitude)
    to_presenter.to_location_result(latitude, longitude)
  end

  def to_dashboard_data
    to_presenter.to_dashboard_data
  end

  def to_export_data(format = :json)
    to_presenter.to_export_data(format)
  end

  # Class methods using services
  def self.find_verified
    LocalBusinessManagementService.get_verified_businesses
  end

  def self.find_by_location(city, state)
    LocalBusinessLocationService.get_businesses_in_city(city) +
    LocalBusinessLocationService.get_businesses_in_state(state)
  end

  def self.search(query, filters = {})
    LocalBusinessManagementService.search_businesses(query, filters)
  end

  def self.find_nearby(latitude, longitude, radius_km = 10)
    LocalBusinessLocationService.get_businesses_in_area(latitude, longitude, radius_km)
  end

  def self.stats
    LocalBusinessManagementService.get_business_stats
  end

  def self.location_stats
    LocalBusinessLocationService.get_location_stats
  end

  def self.popular_locations(limit = 20)
    LocalBusinessLocationService.get_popular_locations(limit)
  end

  def self.analytics_for_location(location_type, location_value)
    LocalBusinessLocationService.get_location_analytics(location_type, location_value)
  end

  private

  def publish_creation_event
    EventPublisher.publish('local_business.created', {
      business_id: id,
      seller_id: seller_id,
      business_name: business_name,
      city: city,
      state: state,
      category: category,
      created_at: created_at
    })
  end

  def publish_update_event
    return unless saved_changes?

    EventPublisher.publish('local_business.updated', {
      business_id: id,
      seller_id: seller_id,
      business_name: business_name,
      city: city,
      state: state,
      category: category,
      changes: saved_changes,
      updated_at: updated_at
    })
  end

  def publish_deletion_event
    EventPublisher.publish('local_business.deleted', {
      business_id: id,
      seller_id: seller_id,
      business_name: business_name,
      city: city,
      state: state,
      deleted_at: Time.current
    })
  end

  def calculate_popularity_score
    score = 0

    # Base score from verification
    score += 50 if verified?

    # Score from ratings
    score += (average_rating || 0) * 10

    # Score from activity
    score += [views_count || 0, 100].min
    score += [interactions_count || 0, 50].min

    # Score from reviews
    score += [reviews_count || 0, 20].min * 2

    # Recency bonus
    score += 10 if created_at > 90.days.ago

    [score, 100].min
  end

  def calculate_market_position(competitors)
    return 'market_leader' if competitors.empty?

    my_score = popularity_score
    avg_competitor_score = competitors.map(&:popularity_score).sum / competitors.size

    if my_score > avg_competitor_score * 1.2
      'market_leader'
    elsif my_score > avg_competitor_score * 0.8
      'competitive'
    else
      'needs_improvement'
    end
  end
end</search_and_replace>
</search_and_replace>

