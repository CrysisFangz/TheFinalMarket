# frozen_string_literal: true

# Context Builder Service - Context Enrichment Engine
#
# This service is responsible for enriching interaction context with additional
# business-relevant information from various sources including customer profiles,
# channel information, historical data, and external services. It implements
# multiple enrichment strategies and provides intelligent caching.
#
# Key Features:
# - Multi-source context enrichment
# - Intelligent caching with TTL strategies
# - Circuit breaker protection for external services
# - Concurrent enrichment for performance
# - Context validation and sanitization
# - Observability and performance metrics
#
# @see InteractionValueObject
# @see ChannelInteraction
class ContextBuilderService
  include Concurrent::Async
  include ServiceResultHelper

  # Enrichment strategies registry
  ENRICHMENT_STRATEGIES = {
    customer_profile: CustomerProfileEnrichmentStrategy,
    channel_info: ChannelInfoEnrichmentStrategy,
    historical_behavior: HistoricalBehaviorEnrichmentStrategy,
    geolocation: GeolocationEnrichmentStrategy,
    device_fingerprinting: DeviceFingerprintingEnrichmentStrategy,
    market_segment: MarketSegmentEnrichmentStrategy,
    personalization: PersonalizationEnrichmentStrategy,
    fraud_detection: FraudDetectionEnrichmentStrategy
  }.freeze

  # Context field mappings for different interaction types
  CONTEXT_MAPPINGS = {
    page_view: [:customer_profile, :channel_info, :device_fingerprinting],
    product_view: [:customer_profile, :channel_info, :historical_behavior, :personalization],
    search: [:customer_profile, :market_segment, :personalization],
    add_to_cart: [:customer_profile, :historical_behavior, :personalization, :fraud_detection],
    checkout_start: [:customer_profile, :historical_behavior, :geolocation, :fraud_detection],
    checkout_complete: [:customer_profile, :historical_behavior, :geolocation, :personalization],
    customer_service: [:customer_profile, :historical_behavior, :personalization],
    email_open: [:customer_profile, :personalization],
    email_click: [:customer_profile, :historical_behavior, :personalization],
    social_engagement: [:customer_profile, :market_segment, :geolocation],
    store_visit: [:customer_profile, :geolocation, :device_fingerprinting],
    phone_call: [:customer_profile, :historical_behavior, :geolocation]
  }.freeze

  # Main context building interface
  # @param interaction [ChannelInteraction, InteractionValueObject] interaction to enrich
  # @param channel [SalesChannel] associated sales channel
  # @param customer [OmnichannelCustomer] associated customer
  # @param additional_context [Hash] additional context to merge
  # @return [Result] monadic result with enriched context
  def self.build(interaction:, channel: nil, customer: nil, additional_context: {})
    instance.async.build_async(interaction, channel, customer, additional_context).value
  end

  # Batch context building for performance
  # @param interactions [Array<Hash>] interactions to enrich
  # @return [Array<Hash>] enriched contexts
  def self.build_batch(interactions)
    instance.build_batch_sync(interactions)
  end

  private

  # Async context building
  def build_async(interaction, channel, customer, additional_context)
    build_sync(interaction, channel, customer, additional_context)
  end

  # Synchronous context building with comprehensive observability
  def build_sync(interaction, channel, customer, additional_context)
    with_observability('context_building') do |span|
      span.set_attribute('interaction.id', interaction.id)
      span.set_attribute('interaction.type', interaction.interaction_type)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Get enrichment strategies for this interaction type
      strategies = determine_enrichment_strategies(interaction)

      # Build base context
      base_context = build_base_context(interaction, channel, customer, additional_context)

      # Apply enrichment strategies
      enriched_context = apply_enrichment_strategies(
        base_context,
        strategies,
        interaction,
        span
      )

      # Validate and sanitize final context
      final_context = validate_and_sanitize_context(enriched_context)

      # Cache the result
      cache_enriched_context(interaction, final_context)

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      span.set_attribute('building.duration_ms', duration * 1000)
      span.set_attribute('enrichment.strategies_applied', strategies.size)

      ObservabilityService.record_metric('context_enriched', 1,
        tags: {
          interaction_type: interaction.interaction_type,
          strategies_count: strategies.size,
          enrichment_time_ms: (duration * 1000).round(2)
        }
      )

      success(final_context)
    end
  end

  # Build base context from interaction and related entities
  def build_base_context(interaction, channel, customer, additional_context)
    base_context = {
      # Core interaction data
      interaction_id: interaction.id,
      interaction_type: interaction.interaction_type,
      occurred_at: interaction.occurred_at,
      interaction_data: interaction.interaction_data,

      # Customer information
      customer_id: interaction.customer_id,
      customer_tier: customer&.tier || 'unknown',
      customer_segment: customer&.segment || 'unknown',
      customer_lifetime_value: customer&.lifetime_value || 0,

      # Channel information
      channel_id: interaction.channel_id,
      channel_name: channel&.name || 'unknown',
      channel_type: channel&.channel_type || 'unknown',
      channel_category: channel&.category || 'unknown',

      # Temporal context
      hour_of_day: interaction.occurred_at.hour,
      day_of_week: interaction.occurred_at.wday,
      month_of_year: interaction.occurred_at.month,
      quarter: quarter_for_month(interaction.occurred_at.month),
      is_weekend: interaction.occurred_at.wday >= 6,
      is_peak_hour: peak_hour?(interaction.occurred_at),
      is_holiday_season: holiday_season?(interaction.occurred_at),

      # Environmental context
      timezone: interaction.occurred_at.time_zone.name,
      season: season_for_month(interaction.occurred_at.month),

      # Processing metadata
      enriched_at: Time.current,
      enrichment_version: '2.1',
      enrichment_source: 'ContextBuilderService'
    }

    # Merge additional context
    base_context.merge!(additional_context)

    base_context
  end

  # Determine which enrichment strategies to apply
  def determine_enrichment_strategies(interaction)
    interaction_type = interaction.interaction_type.to_sym
    strategy_keys = CONTEXT_MAPPINGS[interaction_type] || [:customer_profile, :channel_info]

    strategy_keys.map do |key|
      strategy_class = ENRICHMENT_STRATEGIES[key]
      strategy_class&.new(interaction)
    end.compact
  end

  # Apply enrichment strategies with error isolation
  def apply_enrichment_strategies(base_context, strategies, interaction, span)
    enriched_context = base_context.dup

    strategies.each_with_index do |strategy, index|
      strategy_span = ObservabilityService.create_span("strategy_#{strategy.class.name}")

      begin
        strategy_result = circuit_breaker.execute do
          strategy.enrich(enriched_context, interaction)
        end

        if strategy_result.success?
          enriched_context.merge!(strategy_result.value)
          strategy_span.set_attribute('strategy.success', true)
        else
          strategy_span.set_attribute('strategy.success', false)
          strategy_span.set_attribute('strategy.error', strategy_result.error)

          ObservabilityService.record_metric('enrichment_strategy_failed', 1,
            tags: { strategy: strategy.class.name })
        end

      rescue StandardError => e
        strategy_span.set_attribute('strategy.error', e.message)
        ObservabilityService.record_event('enrichment_strategy_error', {
          strategy: strategy.class.name,
          error: e.message,
          interaction_id: interaction.id
        })
      ensure
        strategy_span.finish
      end
    end

    enriched_context
  end

  # Validate and sanitize final context
  def validate_and_sanitize_context(context)
    sanitized = {}

    # Define allowed context keys and their types
    allowed_keys = {
      # Core fields (required)
      interaction_id: :integer,
      interaction_type: :string,
      occurred_at: :datetime,
      customer_id: :integer,
      channel_id: :integer,

      # Customer fields
      customer_tier: :string,
      customer_segment: :string,
      customer_lifetime_value: :decimal,

      # Channel fields
      channel_name: :string,
      channel_type: :string,
      channel_category: :string,

      # Temporal fields
      hour_of_day: :integer,
      day_of_week: :integer,
      month_of_year: :integer,
      quarter: :integer,
      is_weekend: :boolean,
      is_peak_hour: :boolean,
      is_holiday_season: :boolean,

      # Environmental fields
      timezone: :string,
      season: :string,

      # Enrichment metadata
      enriched_at: :datetime,
      enrichment_version: :string,
      enrichment_source: :string
    }

    # Filter and validate each key
    allowed_keys.each do |key, expected_type|
      next unless context.key?(key)

      value = context[key]

      # Type validation and conversion
      case expected_type
      when :integer
        sanitized[key] = value.to_i if value.respond_to?(:to_i)
      when :decimal
        sanitized[key] = BigDecimal(value.to_s) if value.respond_to?(:to_s)
      when :boolean
        sanitized[key] = ActiveModel::Type::Boolean.new.cast(value)
      when :datetime
        sanitized[key] = value.is_a?(Time) ? value : Time.parse(value.to_s) rescue nil
      else
        sanitized[key] = value.to_s if value.present?
      end
    end

    # Add any additional safe fields that aren't in the allowed list
    context.each do |key, value|
      next if allowed_keys.key?(key) || key.to_s.start_with?('_')

      # Only include simple types for additional fields
      if value.is_a?(String) || value.is_a?(Numeric) || value.is_a?(TrueClass) || value.is_a?(FalseClass)
        sanitized[key] = value
      end
    end

    sanitized
  end

  # Cache enriched context for performance
  def cache_enriched_context(interaction, context)
    cache_key = "enriched_context:#{interaction.id}"
    ttl = determine_cache_ttl(interaction)

    with_caching(cache_key, ttl: ttl) { context }
  end

  # Batch context building implementation
  def build_batch_sync(interactions)
    with_observability('batch_context_building') do |span|
      span.set_attribute('batch.size', interactions.size)

      results = Concurrent::Array.new

      # Group interactions by type for efficient processing
      interactions_by_type = interactions.group_by do |interaction_data|
        interaction_data[:interaction]&.interaction_type || 'unknown'
      end

      interactions_by_type.each do |type, type_interactions|
        async.task do
          type_interactions.each do |interaction_data|
            interaction = interaction_data[:interaction]
            channel = interaction_data[:channel]
            customer = interaction_data[:customer]
            additional_context = interaction_data[:additional_context] || {}

            result = build_sync(interaction, channel, customer, additional_context)
            results << result.value if result.success?
          end
        end
      end

      # Wait for completion
      sleep(0.1) until results.size == interactions.size

      span.set_attribute('batch.success_count', results.size)
      results.to_a
    end
  end

  # Determine cache TTL based on interaction type and context
  def determine_cache_ttl(interaction)
    case interaction.interaction_type.to_sym
    when :page_view, :search, :social_engagement
      5.minutes
    when :product_view, :email_open, :email_click
      15.minutes
    when :add_to_cart, :wishlist_add, :customer_service
      30.minutes
    when :checkout_start, :checkout_complete, :store_visit
      1.hour
    else
      10.minutes
    end
  end

  # Helper methods for temporal calculations

  def quarter_for_month(month)
    ((month - 1) / 3) + 1
  end

  def season_for_month(month)
    case month
    when 12, 1, 2 then 'winter'
    when 3, 4, 5 then 'spring'
    when 6, 7, 8 then 'summer'
    when 9, 10, 11 then 'fall'
    end
  end

  def peak_hour?(timestamp)
    hour = timestamp.hour
    (9..11).include?(hour) || (14..16).include?(hour) || (19..21).include?(hour)
  end

  def holiday_season?(timestamp)
    month = timestamp.month
    day = timestamp.day

    # Holiday periods
    (month == 11 && day >= 15) ||  # Thanksgiving week
    (month == 12 && day >= 15) ||  # Christmas season
    (month == 12 && day <= 5) ||   # New Year
    (month == 2 && day >= 10) ||   # Valentine's week
    (month == 5 && day >= 20) ||   # Memorial Day week
    (month == 7 && day >= 1) ||    # Summer sales
    (month == 11 && day <= 10)     # Early holiday shopping
  end

  # Circuit breaker for external service protection
  def circuit_breaker
    @circuit_breaker ||= ResilienceService.circuit_breaker(
      name: 'context_builder',
      failure_threshold: 3,
      recovery_timeout: 15.seconds
    )
  end

  # Observability wrapper
  def with_observability(operation)
    ObservabilityService.trace(operation) do |span|
      yield span
    end
  end

  # Caching wrapper
  def with_caching(key, ttl: 10.minutes)
    AdaptiveCacheService.fetch(key, ttl: ttl) do
      yield
    end
  end

  # Base enrichment strategy class
  class EnrichmentStrategy
    attr_reader :interaction

    def initialize(interaction)
      @interaction = interaction
    end

    def enrich(context, interaction)
      raise NotImplementedError, 'Subclasses must implement enrich method'
    end

    protected

    def with_external_service(service_name)
      ResilienceService.circuit_breaker(
        name: "#{service_name}_enrichment",
        failure_threshold: 3,
        recovery_timeout: 10.seconds
      ).execute do
        yield
      end
    end

    def cache_strategy_result(strategy_name, context, &block)
      cache_key = "enrichment:#{strategy_name}:#{interaction.id}"
      with_caching(cache_key, ttl: 30.minutes, &block)
    end

    def with_caching(key, ttl: 10.minutes)
      AdaptiveCacheService.fetch(key, ttl: ttl) do
        yield
      end
    end
  end

  # Customer profile enrichment strategy
  class CustomerProfileEnrichmentStrategy < EnrichmentStrategy
    def enrich(context, interaction)
      cache_strategy_result('customer_profile', context) do
        with_external_service('customer_service') do
          customer = interaction.omnichannel_customer

          profile_data = {
            customer_status: customer&.status || 'unknown',
            customer_join_date: customer&.created_at,
            customer_last_login: customer&.last_sign_in_at,
            customer_preferences: customer&.preferences || {},
            customer_marketing_opt_in: customer&.marketing_emails_enabled || false,
            customer_loyalty_tier: customer&.loyalty_tier || 'bronze'
          }

          success(profile_data)
        end
      end
    end
  end

  # Channel information enrichment strategy
  class ChannelInfoEnrichmentStrategy < EnrichmentStrategy
    def enrich(context, interaction)
      cache_strategy_result('channel_info', context) do
        channel = interaction.sales_channel

        channel_data = {
          channel_status: channel&.status || 'unknown',
          channel_priority: channel&.priority || 'normal',
          channel_features: channel&.enabled_features || [],
          channel_performance_score: channel&.performance_score || 0,
          channel_maintenance_mode: channel&.maintenance_mode || false
        }

        success(channel_data)
      end
    end
  end

  # Historical behavior enrichment strategy
  class HistoricalBehaviorEnrichmentStrategy < EnrichmentStrategy
    def enrich(context, interaction)
      cache_strategy_result('historical_behavior', context) do
        customer_id = interaction.customer_id

        # Get recent interaction history
        recent_interactions = InteractionQueryRepository.new
          .recent_by_customer(customer_id, limit: 10)

        behavior_data = {
          interaction_frequency_24h: calculate_frequency(recent_interactions, 24.hours),
          interaction_frequency_7d: calculate_frequency(recent_interactions, 7.days),
          favorite_interaction_types: calculate_favorite_types(recent_interactions),
          average_session_duration: calculate_average_session_duration(recent_interactions),
          customer_lifecycle_stage: determine_lifecycle_stage(recent_interactions),
          engagement_score: calculate_engagement_score(recent_interactions)
        }

        success(behavior_data)
      end
    end

    private

    def calculate_frequency(interactions, time_window)
      cutoff = Time.current - time_window
      interactions.count { |i| i.occurred_at > cutoff }
    end

    def calculate_favorite_types(interactions)
      type_counts = interactions.group_by(&:interaction_type)
                               .transform_values(&:count)
                               .sort_by { |_, count| -count }
                               .first(3)
                               .to_h
      type_counts.keys
    end

    def calculate_average_session_duration(interactions)
      # Simplified calculation - would need session grouping logic
      5.5 # minutes (example)
    end

    def determine_lifecycle_stage(interactions)
      return 'new' if interactions.empty?

      days_since_first = (Time.current - interactions.last.occurred_at).to_i / 86400

      case days_since_first
      when 0..7 then 'new'
      when 8..30 then 'engaged'
      when 31..90 then 'loyal'
      when 91..365 then 'champion'
      else 'at_risk'
      end
    end

    def calculate_engagement_score(interactions)
      return 0 if interactions.empty?

      # Simple scoring based on diversity and frequency
      type_diversity = interactions.map(&:interaction_type).uniq.count
      recent_frequency = calculate_frequency(interactions, 7.days)

      [(type_diversity * 10) + recent_frequency, 100].min
    end
  end

  # Additional enrichment strategies would be implemented here...
  # GeolocationEnrichmentStrategy, DeviceFingerprintingEnrichmentStrategy, etc.

  # Placeholder for remaining strategies
  class GeolocationEnrichmentStrategy < EnrichmentStrategy
    def enrich(context, interaction)
      success(geolocation_data: 'enriched')
    end
  end

  class DeviceFingerprintingEnrichmentStrategy < EnrichmentStrategy
    def enrich(context, interaction)
      success(device_info: 'enriched')
    end
  end

  class MarketSegmentEnrichmentStrategy < EnrichmentStrategy
    def enrich(context, interaction)
      success(market_data: 'enriched')
    end
  end

  class PersonalizationEnrichmentStrategy < EnrichmentStrategy
    def enrich(context, interaction)
      success(personalization_data: 'enriched')
    end
  end

  class FraudDetectionEnrichmentStrategy < EnrichmentStrategy
    def enrich(context, interaction)
      success(fraud_score: 0.05) # Low risk score
    end
  end
end