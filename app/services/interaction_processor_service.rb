# frozen_string_literal: true

# Interaction Processor Service - Core Business Logic
#
# This service encapsulates all business logic for processing channel interactions,
# implementing the Interactor pattern with monadic error handling and comprehensive
# observability. It coordinates between value calculation, context enrichment,
# validation, and event publishing.
#
# Key Features:
# - Monadic error handling with Result pattern
# - Comprehensive observability and tracing
# - Circuit breaker integration for antifragility
# - Event sourcing for audit trails
# - Hyper-concurrent processing capabilities
# - Adaptive caching integration
# - Rate limiting and bulkhead isolation
#
# @see InteractionValueObject
# @see ValueCalculationService
# @see ContextBuilderService
class InteractionProcessorService
  include Concurrent::Async
  include ServiceResultHelper

  # Main interaction processing interface
  # @param interaction [ChannelInteraction, InteractionValueObject] interaction to process
  # @return [Result] monadic result with success/failure information
  def self.process(interaction)
    instance.async.process_async(interaction).value
  rescue StandardError => e
    handle_processing_error(e, interaction)
  end

  # Batch processing for high-throughput scenarios
  # @param interactions [Array] array of interactions to process
  # @param batch_size [Integer] size of processing batches
  # @return [Result] result with processing statistics
  def self.process_batch(interactions, batch_size: 100)
    instance.process_batch_sync(interactions, batch_size)
  end

  # Health check for service readiness
  # @return [Boolean] true if service is operational
  def self.healthy?
    instance.healthy?
  end

  private

  # Async processing implementation
  def process_async(interaction)
    process_sync(interaction)
  end

  # Synchronous processing with full observability
  def process_sync(interaction)
    with_observability('interaction_processing') do |span|
      span.set_attribute('interaction.id', interaction.id)
      span.set_attribute('interaction.type', interaction.interaction_type)

      # Rate limiting check
      return rate_limit_error(interaction) unless rate_limit_allows?(interaction)

      # Circuit breaker protection
      circuit_breaker.execute do
        with_bulkhead do
          execute_processing_pipeline(interaction, span)
        end
      end
    end
  end

  # Execute the complete processing pipeline
  def execute_processing_pipeline(interaction, span)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # Step 1: Validation
    validation_result = validate_interaction(interaction)
    return validation_result unless validation_result.success?

    # Step 2: Value calculation
    value_result = calculate_value(interaction, span)
    return value_result unless value_result.success?

    # Step 3: Context enrichment
    context_result = enrich_context(interaction, span)
    return context_result unless context_result.success?

    # Step 4: Event publishing
    event_result = publish_events(interaction, value_result.value, context_result.value)
    return event_result unless event_result.success?

    # Step 5: Caching and metrics
    finalize_processing(interaction, value_result.value, start_time)

    # Return successful result
    success(
      interaction: interaction,
      value_score: value_result.value,
      enriched_context: context_result.value,
      processing_time_ms: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000
    )
  end

  # Comprehensive interaction validation
  def validate_interaction(interaction)
    with_observability('interaction_validation') do |span|
      errors = []

      # Basic presence validation
      errors << 'interaction_type is required' if interaction.interaction_type.blank?
      errors << 'occurred_at is required' if interaction.occurred_at.blank?
      errors << 'customer_id is required' if interaction.customer_id.blank?
      errors << 'channel_id is required' if interaction.channel_id.blank?

      # Business rule validation
      errors << 'interaction too old' if interaction_age_too_old?(interaction)
      errors << 'interaction in future' if interaction_in_future?(interaction)
      errors << 'invalid interaction type' unless valid_interaction_type?(interaction.interaction_type)

      # Security validation
      errors << 'suspicious activity detected' unless security_check_passes?(interaction)

      if errors.any?
        span.set_attribute('validation.errors', errors.size)
        ObservabilityService.record_metric('interaction_validation_failed', 1, tags: { error_count: errors.size })
        return failure(errors.join(', '))
      end

      success(true)
    end
  end

  # Value calculation with strategy pattern
  def calculate_value(interaction, span)
    with_observability('value_calculation') do |calc_span|
      calc_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Prepare context for value calculation
      context = build_value_context(interaction)

      # Use adaptive caching for performance
      cache_key = "value_calc:#{interaction.id}:#{interaction.interaction_type}"

      value_score = with_caching(cache_key) do
        ValueCalculationService.calculate(interaction.interaction_type, context)
      end

      calc_duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - calc_start
      calc_span.set_attribute('calculation.duration_ms', calc_duration * 1000)

      success(value_score)
    end
  end

  # Context enrichment with external services
  def enrich_context(interaction, span)
    with_observability('context_enrichment') do |enrich_span|
      enrich_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Use context builder service for enrichment
      enriched_context = ContextBuilderService.build(
        interaction: interaction,
        channel: interaction.sales_channel,
        customer: interaction.omnichannel_customer,
        additional_context: {
          processing_timestamp: Time.current,
          enrichment_version: '2.0'
        }
      )

      enrich_duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - enrich_start
      enrich_span.set_attribute('enrichment.duration_ms', enrich_duration * 1000)

      success(enriched_context)
    end
  end

  # Event publishing for audit trails
  def publish_events(interaction, value_score, context)
    with_observability('event_publishing') do |event_span|
      events = []

      # Create processing event
      processed_event = DomainEvents::EventFactory.interaction_processed(
        interaction.id,
        processing_time_ms: event_span.get_attribute('processing.duration_ms') || 0,
        value_score: value_score,
        context_data: context,
        processor_version: '2.0'
      )
      events << processed_event

      # Create value calculation event if score changed
      if interaction_value_changed?(interaction, value_score)
        value_event = DomainEvents::EventFactory.value_recalculated(
          interaction.id,
          interaction.value_score,
          value_score,
          'realtime_recalculation'
        )
        events << value_event
      end

      # Publish events asynchronously
      publish_events_async(events)

      event_span.set_attribute('events_published', events.size)
      success(events)
    end
  end

  # Finalize processing with caching and metrics
  def finalize_processing(interaction, value_score, start_time)
    total_duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    # Update caches
    update_interaction_caches(interaction, value_score)

    # Record comprehensive metrics
    record_processing_metrics(interaction, value_score, total_duration)

    # Emit high-value interaction notification
    notify_high_value_interaction(interaction, value_score) if value_score >= 50
  end

  # Batch processing implementation
  def process_batch_sync(interactions, batch_size)
    with_observability('batch_processing') do |span|
      span.set_attribute('batch.size', interactions.size)
      span.set_attribute('batch.batch_size', batch_size)

      results = Concurrent::Array.new
      errors = Concurrent::Array.new
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Process in batches for memory efficiency
      interactions.each_slice(batch_size) do |batch|
        batch.each do |interaction|
          async.task do
            result = process_sync(interaction)
            if result.success?
              results << result.value
            else
              errors << { interaction: interaction, error: result.error }
            end
          end
        end

        # Wait for batch to complete before processing next
        sleep(0.01) while results.size + errors.size < batch.size * (results.size + errors.size) / batch.size
      end

      total_duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      span.set_attribute('batch.duration_ms', total_duration * 1000)
      span.set_attribute('batch.success_count', results.size)
      span.set_attribute('batch.error_count', errors.size)

      success(
        processed_count: results.size,
        error_count: errors.size,
        total_duration_ms: total_duration * 1000,
        results: results.to_a,
        errors: errors.to_a
      )
    end
  end

  # Build context for value calculation
  def build_value_context(interaction)
    {
      customer_id: interaction.customer_id,
      channel_id: interaction.channel_id,
      interaction_data: interaction.interaction_data,
      occurred_at: interaction.occurred_at,
      customer_tier: interaction.omnichannel_customer&.tier,
      channel_type: interaction.sales_channel&.channel_type,
      device_type: extract_device_type(interaction.interaction_data),
      time_of_day: interaction.occurred_at.hour,
      day_of_week: interaction.occurred_at.wday,
      is_peak_hour: peak_hour?(interaction.occurred_at),
      is_promotional_period: promotional_period?(interaction.occurred_at)
    }
  end

  # Extract device type from interaction data
  def extract_device_type(interaction_data)
    user_agent = interaction_data['user_agent'] || ''
    if user_agent.include?('Mobile')
      :mobile
    elsif user_agent.include?('Tablet')
      :tablet
    else
      :desktop
    end
  end

  # Check if time is peak hour
  def peak_hour?(timestamp)
    hour = timestamp.hour
    (9..11).include?(hour) || (14..16).include?(hour)
  end

  # Check if time is promotional period
  def promotional_period?(timestamp)
    # Example: Holiday season, special events, etc.
    month = timestamp.month
    day = timestamp.day
    (month == 12 && day >= 15) || (month == 11 && day >= 20)
  end

  # Check if interaction value changed significantly
  def interaction_value_changed?(interaction, new_score)
    current_score = interaction.value_score
    return true if current_score.nil?

    change_percentage = ((new_score - current_score).abs / current_score.to_f) * 100
    change_percentage > 10 # Changed by more than 10%
  end

  # Update various caches after processing
  def update_interaction_caches(interaction, value_score)
    # Update value score cache
    cache_key = "interaction_value:#{interaction.id}"
    with_caching(cache_key) { value_score }

    # Update recent interactions cache
    recent_key = "recent_interactions:#{interaction.customer_id}"
    with_caching(recent_key, ttl: 30.minutes) do
      recent_interactions_for_customer(interaction.customer_id)
    end

    # Update high-value interactions cache if applicable
    if value_score >= 50
      high_value_key = "high_value_interactions:#{interaction.customer_id}"
      with_caching(high_value_key, ttl: 1.hour) do
        high_value_interactions_for_customer(interaction.customer_id)
      end
    end
  end

  # Record comprehensive processing metrics
  def record_processing_metrics(interaction, value_score, duration)
    tags = {
      interaction_type: interaction.interaction_type,
      customer_tier: interaction.omnichannel_customer&.tier || 'unknown',
      channel_type: interaction.sales_channel&.channel_type || 'unknown',
      value_tier: value_tier(value_score)
    }

    ObservabilityService.record_metric('interaction_processed', 1, tags: tags)
    ObservabilityService.record_metric('interaction_processing_time', duration * 1000, tags: tags)
    ObservabilityService.record_metric('interaction_value_score', value_score, tags: tags)
  end

  # Get value tier for metrics
  def value_tier(score)
    case score
    when 0..10 then 'low'
    when 11..30 then 'medium'
    when 31..70 then 'high'
    else 'premium'
    end
  end

  # Notify about high-value interactions
  def notify_high_value_interaction(interaction, value_score)
    # Async notification to avoid blocking processing
    async.task do
      NotificationService.notify_high_value_interaction(interaction, value_score)
    end
  end

  # Publish events asynchronously
  def publish_events_async(events)
    async.task do
      events.each do |event|
        EventPublisher.publish(event)
      end
    end
  end

  # Get recent interactions for customer (cached)
  def recent_interactions_for_customer(customer_id)
    InteractionQueryRepository.new.recent_by_customer(customer_id, limit: 10)
  end

  # Get high-value interactions for customer (cached)
  def high_value_interactions_for_customer(customer_id)
    InteractionQueryRepository.new.high_value_by_customer(customer_id, limit: 5)
  end

  # Check if interaction age is too old for processing
  def interaction_age_too_old?(interaction)
    interaction.occurred_at < 1.year.ago
  end

  # Check if interaction timestamp is in the future
  def interaction_in_future?(interaction)
    interaction.occurred_at > Time.current + 1.minute
  end

  # Validate interaction type
  def valid_interaction_type?(type)
    ChannelInteraction.interaction_types.keys.include?(type.to_s)
  end

  # Security validation
  def security_check_passes?(interaction)
    # Basic security checks
    return false if interaction.interaction_data['suspicious_activity']

    # Rate limiting check
    rate_limit_allows?(interaction)
  end

  # Rate limiting check
  def rate_limit_allows?(interaction)
    RateLimiterService.allow?(
      key: "interaction_processing:#{interaction.customer_id}",
      limit: 1000,
      window: 1.hour
    )
  end

  # Circuit breaker integration
  def circuit_breaker
    @circuit_breaker ||= ResilienceService.circuit_breaker(
      name: 'interaction_processor',
      failure_threshold: 5,
      recovery_timeout: 30.seconds
    )
  end

  # Bulkhead for resource isolation
  def with_bulkhead
    BulkheadService.execute(pool: :interaction_processing) do
      yield
    end
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

  # Handle processing errors
  def self.handle_processing_error(error, interaction)
    ObservabilityService.record_event('interaction_processing_error', {
      error_class: error.class.name,
      error_message: error.message,
      interaction_id: interaction&.id,
      interaction_type: interaction&.interaction_type
    })

    failure("Processing failed: #{error.message}")
  end

  # Rate limit exceeded error
  def rate_limit_error(interaction)
    ObservabilityService.record_metric('interaction_rate_limited', 1,
      tags: { customer_id: interaction.customer_id })

    failure('Rate limit exceeded')
  end

  # Health check implementation
  def healthy?
    circuit_breaker.closed? && dependencies_healthy?
  end

  # Check if all dependencies are healthy
  def dependencies_healthy?
    ValueCalculationService.healthy? &&
    ContextBuilderService.healthy? &&
    EventPublisher.healthy? rescue false
  end
end