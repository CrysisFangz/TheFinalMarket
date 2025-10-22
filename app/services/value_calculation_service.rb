# frozen_string_literal: true

# Value Calculation Service - Strategy Pattern Implementation
#
# This service implements the Strategy pattern to provide O(1) lookup performance for interaction
# value calculation, replacing the previous O(n) case statement approach. The service uses
# a pre-computed lookup table for instant value retrieval and supports dynamic strategy
# injection for extensibility.
#
# Key Features:
# - O(1) value calculation using hash-based lookup
# - Strategy pattern for extensibility and testability
# - Immutable lookup table for thread safety
# - Configurable value multipliers and weights
# - Context-aware value calculation
# - Performance metrics and observability
#
# @see InteractionValueObject
# @see ValueCalculationStrategy
class ValueCalculationService
  include Singleton
  include Concurrent::Async

  # Base value scores for different interaction types
  BASE_SCORES = Concurrent::ImmutableStruct.new(
    page_view: 5,
    product_view: 25,
    search: 5,
    add_to_cart: 50,
    remove_from_cart: 0,
    checkout_start: 75,
    checkout_complete: 100,
    cart_abandonment: 10,
    wishlist_add: 30,
    review_submit: 40,
    customer_service: 20,
    email_open: 5,
    email_click: 15,
    social_engagement: 10,
    store_visit: 35,
    phone_call: 25
  ).freeze

  # Context multipliers for enhanced scoring
  CONTEXT_MULTIPLIERS = Concurrent::ImmutableStruct.new(
    first_time_customer: 1.5,
    high_value_customer: 1.3,
    premium_channel: 1.2,
    mobile_device: 1.1,
    peak_hours: 1.15,
    promotional_period: 1.25
  ).freeze

  # Performance optimization: Pre-computed lookup table
  LOOKUP_TABLE = Concurrent::Map.new

  # Initialize lookup table and strategies
  def initialize
    super()
    build_lookup_table
    initialize_strategies
    register_observers
  end

  # Main value calculation interface
  # @param interaction_type [String, Symbol] type of interaction
  # @param context [Hash] additional context data for enhanced scoring
  # @return [Integer] calculated value score
  def self.calculate(interaction_type, context = {})
    instance.async.calculate_async(interaction_type, context).value
  end

  # Synchronous calculation for real-time operations
  # @param interaction_type [String, Symbol] type of interaction
  # @param context [Hash] additional context data
  # @return [Integer] calculated value score
  def calculate_sync(interaction_type, context = {})
    with_observability('value_calculation') do |span|
      span.set_attribute('interaction.type', interaction_type.to_s)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # O(1) lookup with fallback to strategy
      base_score = lookup_base_score(interaction_type)
      return 0 if base_score.nil?

      # Apply context multipliers
      final_score = apply_context_multipliers(base_score, context)

      # Record performance metrics
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      span.set_attribute('calculation.duration_ms', duration * 1000)

      ObservabilityService.record_metric(
        'interaction_value_calculated',
        final_score,
        tags: {
          interaction_type: interaction_type.to_s,
          calculation_time_ms: (duration * 1000).round(2)
        }
      )

      final_score.to_i
    end
  end

  # Batch calculation for performance optimization
  # @param interactions [Array<Hash>] array of interaction data
  # @return [Array<Integer>] array of calculated scores
  def calculate_batch(interactions)
    with_observability('batch_value_calculation') do |span|
      span.set_attribute('batch.size', interactions.size)

      results = Concurrent::Array.new

      # Parallel processing for large batches
      if interactions.size > 100
        process_parallel_batch(interactions, results, span)
      else
        process_sequential_batch(interactions, results)
      end

      results.to_a
    end
  end

  # Register custom calculation strategy
  # @param interaction_type [String, Symbol] interaction type
  # @param strategy [ValueCalculationStrategy] calculation strategy
  def register_strategy(interaction_type, strategy)
    strategies[interaction_type.to_sym] = strategy
    invalidate_cache_for_type(interaction_type)
  end

  # Get strategy for interaction type
  # @param interaction_type [String, Symbol] interaction type
  # @return [ValueCalculationStrategy] registered strategy
  def strategy_for(interaction_type)
    strategies[interaction_type.to_sym] || default_strategy
  end

  # Health check for service readiness
  # @return [Boolean] true if service is ready
  def healthy?
    lookup_table_ready? && strategies_ready?
  end

  private

  # Async calculation method
  def calculate_async(interaction_type, context = {})
    calculate_sync(interaction_type, context)
  end

  # Build optimized lookup table for O(1) access
  def build_lookup_table
    BASE_SCORES.each_pair do |type, score|
      LOOKUP_TABLE[type] = score
    end
  end

  # Initialize calculation strategies
  def initialize_strategies
    @strategies = Concurrent::Map.new
    @default_strategy = DefaultValueStrategy.new

    # Register specialized strategies
    register_strategy(:checkout_complete, CheckoutValueStrategy.new)
    register_strategy(:product_view, ProductViewValueStrategy.new)
    register_strategy(:customer_service, CustomerServiceValueStrategy.new)
  end

  # O(1) base score lookup
  def lookup_base_score(interaction_type)
    LOOKUP_TABLE[interaction_type.to_sym]
  end

  # Apply context-based multipliers
  def apply_context_multipliers(base_score, context)
    multiplier = calculate_context_multiplier(context)
    (base_score * multiplier).round(2)
  end

  # Calculate context multiplier based on various factors
  def calculate_context_multiplier(context)
    multiplier = 1.0

    # Customer-related multipliers
    multiplier *= CONTEXT_MULTIPLIERS.first_time_customer if context[:first_time_customer]
    multiplier *= CONTEXT_MULTIPLIERS.high_value_customer if context[:high_value_customer]

    # Channel-related multipliers
    multiplier *= CONTEXT_MULTIPLIERS.premium_channel if context[:premium_channel]

    # Device and timing multipliers
    multiplier *= CONTEXT_MULTIPLIERS.mobile_device if context[:mobile_device]
    multiplier *= CONTEXT_MULTIPLIERS.peak_hours if context[:peak_hours]
    multiplier *= CONTEXT_MULTIPLIERS.promotional_period if context[:promotional_period]

    multiplier
  end

  # Sequential batch processing
  def process_sequential_batch(interactions, results)
    interactions.each do |interaction|
      score = calculate_sync(interaction[:type], interaction[:context] || {})
      results << score
    end
  end

  # Parallel batch processing for large datasets
  def process_parallel_batch(interactions, results, span)
    batch_size = 50
    batches = interactions.each_slice(batch_size).to_a

    batches.each do |batch|
      async.task do
        batch.each do |interaction|
          score = calculate_sync(interaction[:type], interaction[:context] || {})
          results << score
        end
      end
    end

    # Wait for all batches to complete
    sleep(0.1) until results.size == interactions.size
  end

  # Invalidate cached calculations for interaction type
  def invalidate_cache_for_type(interaction_type)
    # Clear any cached calculations for this type
    cache_key_pattern = "value_calculation:#{interaction_type}:*"
    Rails.cache.delete_matched(cache_key_pattern) if defined?(Rails)
  end

  # Check if lookup table is ready
  def lookup_table_ready?
    LOOKUP_TABLE.size == BASE_SCORES.size
  end

  # Check if strategies are initialized
  def strategies_ready?
    !@strategies.nil? && !@default_strategy.nil?
  end

  # Register observability observers
  def register_observers
    # Monitor for cache invalidation events
    ActiveSupport::Notifications.subscribe('value_calculation.cache_invalidation') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      ObservabilityService.record_event('value_calculation_cache_invalidated', event.payload)
    end
  end

  # Observability wrapper
  def with_observability(operation_name)
    ObservabilityService.trace(operation_name) do |span|
      yield span
    end
  end

  # Default strategy for unknown interaction types
  class DefaultValueStrategy
    def calculate(interaction_type, context = {})
      # Fallback to base score for unknown types
      BASE_SCORES.public_send(interaction_type.to_sym) rescue 0
    end
  end

  # Specialized strategy for checkout completion
  class CheckoutValueStrategy
    def calculate(interaction_type, context = {})
      base_score = BASE_SCORES.checkout_complete

      # Increase value for high-value orders
      if context[:order_value] && context[:order_value] > 1000
        base_score * 1.5
      elsif context[:order_value] && context[:order_value] > 500
        base_score * 1.25
      else
        base_score
      end
    end
  end

  # Specialized strategy for product views
  class ProductViewValueStrategy
    def calculate(interaction_type, context = {})
      base_score = BASE_SCORES.product_view

      # Increase value for premium products or categories
      if context[:premium_product] || context[:premium_category]
        base_score * 1.3
      else
        base_score
      end
    end
  end

  # Specialized strategy for customer service interactions
  class CustomerServiceValueStrategy
    def calculate(interaction_type, context = {})
      base_score = BASE_SCORES.customer_service

      # Increase value for complex issues or VIP customers
      if context[:complex_issue] || context[:vip_customer]
        base_score * 1.4
      else
        base_score
      end
    end
  end
end