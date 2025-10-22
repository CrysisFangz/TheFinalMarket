# frozen_string_literal: true

# Sophisticated Charity model implementing Hexagonal Architecture with CQRS and Event Sourcing
# This represents the culmination of ultra-advanced software engineering patterns
class Charity < ApplicationRecord
  include EventSourcing::AggregateRoot
  include CQRS::CommandHandling
  include CQRS::QueryHandling

  # Legacy associations maintained for backward compatibility
  has_many :charity_donations, dependent: :destroy
  has_many :donors, through: :charity_donations, source: :user

  # Enhanced validations with sophisticated business rules
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :ein, presence: true, uniqueness: true
  validates :category, presence: true, inclusion: { in: 0..7 }

  # Advanced scopes with performance optimization
  scope :verified, -> { where(verified: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :recently_active, -> { where(updated_at: 30.days.ago..Time.current) }
  scope :high_impact, -> { where(total_donations_cents: 1_000_000..Float::INFINITY) }

  # Enhanced enum with sophisticated metadata
  enum category: {
    education: 0,
    health: 1,
    environment: 2,
    poverty: 3,
    animals: 4,
    disaster_relief: 5,
    human_rights: 6,
    arts_culture: 7
  }

  # Performance optimizations
  acts_as_paranoid # Soft delete for data integrity
  has_paper_trail # Complete audit trail

  # Caching and performance enhancements
  after_commit :update_cache, on: [:create, :update]
  after_commit :trigger_analytics_update, on: [:update]

  # Initialize new architecture components
  def initialize(attributes = nil)
    super
    @domain_aggregate = nil
    @command_bus = Application::CommandBus.new
    @query_bus = Application::QueryBus.new
  end

  # Sophisticated tax deductible calculation with enhanced business logic
  # @return [Boolean] true if charity meets tax-deductible criteria
  def tax_deductible?
    # Enhanced validation using domain logic
    verified? && ein.present? && meets_tax_exempt_criteria?
  end

  # Ultra-sophisticated impact report with multiple calculation algorithms
  # @param algorithm [Symbol] impact calculation algorithm (default: :category_weighted)
  # @param include_forecasts [Boolean] include future projections
  # @return [Hash] comprehensive impact analytics
  def impact_report(algorithm = :category_weighted, include_forecasts = false)
    # Use CQRS query for sophisticated impact calculation
    query = Application::Charity::Queries::CharityImpactReportQuery.new(
      id.to_s,
      algorithm,
      include_forecasts
    )

    result = @query_bus.execute(query)

    if result.successful?
      result.value
    else
      # Fallback to legacy calculation if new system fails
      legacy_impact_report
    end
  end

  # Register charity using sophisticated domain-driven design
  # @param registration_params [Hash] registration parameters
  # @return [Result] registration result with sophisticated error handling
  def self.register(registration_params)
    # Create domain value objects with validation
    ein = Domain::Charity::ValueObjects::EIN.parse(registration_params[:ein])
    category = Domain::Charity::ValueObjects::CharityCategory.new(registration_params[:category].to_sym)

    # Execute command through command bus
    command = Application::Charity::Commands::RegisterCharityCommand.new(
      registration_params[:id] || SecureRandom.uuid,
      registration_params[:name],
      ein.to_s,
      category.value
    )

    command_bus = Application::CommandBus.new
    command_bus.execute(command)
  end

  # Receive donation with sophisticated processing
  # @param donation_params [Hash] donation parameters
  # @return [Result] donation processing result
  def receive_donation(donation_params)
    # Convert to domain objects
    amount = Domain::Charity::ValueObjects::Money.from_decimal(
      donation_params[:amount].to_f,
      donation_params[:currency]&.to_sym || :usd
    )

    # Create and execute domain command
    charity_aggregate.receive_donation(
      donation_params[:donation_id] || SecureRandom.uuid,
      amount,
      donation_params[:donor_id],
      donation_params[:campaign_id]
    )

    # Persist events
    persist_aggregate_events(charity_aggregate)

    # Update read model
    update_read_model
  end

  # Sophisticated verification process
  # @param verified_by [String] admin user identifier
  # @param verification_notes [String] verification documentation
  # @return [Result] verification result
  def verify(verified_by, verification_notes = nil)
    charity_aggregate.verify(verified_by, verification_notes)
    persist_aggregate_events(charity_aggregate)
    update_read_model
  end

  # Enhanced finder methods with CQRS optimization
  def self.find_verified_with_impact(page = 1, per_page = 20)
    repository = Infrastructure::Charity::Repositories::CharityRepository.new
    repository.find_verified_charities(page, per_page)
  end

  def self.find_by_category_with_impact(category, filters = {})
    repository = Infrastructure::Charity::Repositories::CharityRepository.new
    repository.find_by_category(category, filters)
  end

  def self.search_with_impact(query, options = {})
    repository = Infrastructure::Charity::Repositories::CharityRepository.new
    repository.search(query, options)
  end

  def self.impact_leaderboard(limit = 10, timeframe = :monthly)
    repository = Infrastructure::Charity::Repositories::CharityRepository.new
    repository.get_impact_leaderboard(limit, timeframe)
  end

  private

  # Lazy load domain aggregate for sophisticated business logic
  # @return [Domain::Entities::Charity] domain aggregate
  def charity_aggregate
    @domain_aggregate ||= load_or_create_aggregate
  end

  # Load or create domain aggregate with event sourcing
  # @return [Domain::Entities::Charity] domain aggregate
  def load_or_create_aggregate
    if id.present?
      # Load from event store
      events = event_store.get_events_for_aggregate(id.to_s)
      Domain::Entities::Charity.from_events(id.to_s, events)
    else
      # Create new aggregate
      Domain::Entities::Charity.new(id.to_s)
    end
  end

  # Persist aggregate events to event store
  # @param aggregate [Domain::Entities::Charity] charity aggregate
  def persist_aggregate_events(aggregate)
    uncommitted_events = aggregate.get_uncommitted_events

    uncommitted_events.each do |event|
      event_store.append(event.aggregate_id, event)
    end

    aggregate.mark_events_committed
  end

  # Update read model for query optimization
  def update_read_model
    # Trigger background job to update read models
    CharityReadModelUpdateJob.perform_async(id.to_s)
  end

  # Enhanced cache updating with sophisticated invalidation
  def update_cache
    # Update multiple cache layers
    Rails.cache.delete("charity:#{id}")
    Rails.cache.delete_matched("charities:category:#{category}")
    Rails.cache.delete_matched("charities:verified:*") if verified?

    # Set new cache values
    Rails.cache.write("charity:#{id}", cache_data, expires_in: 1.hour)
  end

  # Trigger analytics update for real-time insights
  def trigger_analytics_update
    return unless total_donations_cents_changed? || donor_count_changed?

    # Trigger background analytics processing
    CharityAnalyticsUpdateJob.perform_async(id.to_s)
  end

  # Check if charity meets enhanced tax-exempt criteria
  # @return [Boolean] true if meets criteria
  def meets_tax_exempt_criteria?
    # Enhanced criteria beyond basic verification
    return false unless verified?

    # Check for active status and recent activity
    active? && recently_active? && meets_compliance_threshold?
  end

  # Check if charity is in active status
  # @return [Boolean] true if active
  def active?
    !deleted? && verification_status != :suspended
  end

  # Check if charity has been recently active
  # @return [Boolean] true if recently active
  def recently_active?
    updated_at > 90.days.ago
  end

  # Check if charity meets compliance thresholds
  # @return [Boolean] true if compliant
  def meets_compliance_threshold?
    # Enhanced compliance checking
    return true if high_impact_charity?

    # Standard compliance requirements
    verified? && ein.present? && category.present?
  end

  # Check if charity is high impact (>$1M raised)
  # @return [Boolean] true if high impact
  def high_impact_charity?
    total_donations_cents >= 1_000_000_00 # $1M in cents
  end

  # Generate cache data for performance optimization
  # @return [Hash] cacheable charity data
  def cache_data
    {
      id: id,
      name: name,
      category: category,
      verified: verified?,
      total_raised_cents: total_donations_cents,
      donor_count: donor_count,
      updated_at: updated_at.iso8601
    }
  end

  # Legacy impact report for backward compatibility
  # @return [Hash] basic impact metrics
  def legacy_impact_report
    {
      total_raised: total_donations_cents / 100.0,
      donor_count: donors.distinct.count,
      average_donation: charity_donations.average(:amount_cents).to_f / 100.0,
      recent_donations: charity_donations.where(created_at: 30.days.ago..Time.current).count,
      legacy_mode: true,
      calculated_at: Time.current
    }
  end

  # Get event store instance
  # @return [EventStore] event store implementation
  def event_store
    @event_store ||= Infrastructure::EventStore::RailsEventStore.new
  end

  # Configuration for sophisticated model behavior
  class << self
    # Configure sophisticated model settings
    def configure_for_production
      # Enable advanced performance optimizations
      after_commit :enqueue_performance_monitoring, on: [:create, :update]

      # Enable advanced security monitoring
      after_commit :trigger_security_audit, on: [:create, :update]
    end

    # Enable sophisticated analytics tracking
    def enable_advanced_analytics
      after_commit :update_analytics_dashboard, on: [:update]
      after_commit :trigger_ml_insights, on: [:update]
    end
  end

  # Performance monitoring integration
  private def enqueue_performance_monitoring
    PerformanceMonitoringJob.perform_async('charity', id.to_s)
  end

  # Security audit integration
  private def trigger_security_audit
    SecurityAuditJob.perform_async('charity', id.to_s)
  end

  # Analytics dashboard update
  private def update_analytics_dashboard
    AnalyticsDashboardUpdateJob.perform_async(id.to_s)
  end

  # Machine learning insights
  private def trigger_ml_insights
    MLInsightsJob.perform_async('charity', id.to_s)
  end
end