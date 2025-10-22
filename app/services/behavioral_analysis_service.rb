# frozen_string_literal: true

# Main Behavioral Analysis Service - Hexagonal Architecture Application Layer
# Orchestrates multiple anomaly detection strategies for comprehensive behavioral analysis
# Implements CQRS pattern with separate read/write operations
class BehavioralAnalysisService
  include ServiceResultHelper

  # Service dependencies - injected for testability and modularity
  attr_reader :repository, :event_publisher, :cache_service, :circuit_breaker

  def initialize(
    repository: BehavioralPatternRepository.new,
    event_publisher: EventPublisher,
    cache_service: CacheService,
    circuit_breaker: CircuitBreakerService
  )
    @repository = repository
    @event_publisher = event_publisher
    @cache_service = cache_service
    @circuit_breaker = circuit_breaker
  end

  # Main entry point for behavioral analysis following CQRS pattern
  def self.call(user, options = {})
    new.call(user, options)
  end

  def call(user, options = {})
    @user = user
    @options = default_options.merge(options)
    @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # Execute analysis with circuit breaker protection
    execute_with_circuit_breaker do
      perform_behavioral_analysis
    end
  rescue StandardError => e
    handle_analysis_error(e)
  end

  # Query method for retrieving behavioral patterns (CQRS Read)
  def self.find_patterns(user, filters = {})
    new.find_patterns(user, filters)
  end

  def find_patterns(user, filters = {})
    @user = user
    @filters = filters

    cache_key = generate_cache_key(:patterns, filters)

    @cache_service.fetch(cache_key, ttl: 300) do # 5 minute cache
      @repository.find_by_user(user, normalized_filters)
    end
  end

  # Query method for pattern statistics (CQRS Read)
  def self.get_statistics(user, time_range: 30.days)
    new.get_statistics(user, time_range)
  end

  def get_statistics(user, time_range)
    @user = user
    @time_range = time_range

    cache_key = generate_cache_key(:statistics, time_range)

    @cache_service.fetch(cache_key, ttl: 600) do # 10 minute cache
      calculate_pattern_statistics
    end
  end

  private

  # Main analysis orchestration method
  def perform_behavioral_analysis
    # Gather comprehensive user behavior data
    behavior_data = gather_behavior_data

    return failure('Insufficient behavior data for analysis') if insufficient_data?(behavior_data)

    # Execute multiple detection strategies in parallel for performance
    detection_results = execute_detection_strategies(behavior_data)

    # Aggregate and correlate results using machine learning ensemble
    analysis_result = aggregate_detection_results(detection_results)

    # Persist patterns if anomalies detected
    persist_behavioral_patterns(analysis_result) if analysis_result[:anomalous]

    # Publish domain events for event sourcing
    publish_analysis_events(analysis_result)

    # Return comprehensive analysis result
    success(analysis_result)
  end

  def gather_behavior_data
    @circuit_breaker.execute_with_fallback(fallback_data) do
      {
        user: @user,
        behavior_metrics: fetch_behavior_metrics,
        historical_patterns: fetch_historical_patterns,
        time_series_data: fetch_time_series_data,
        current_time: Time.current,
        sensitivity_level: @options[:sensitivity_level] || :moderate,
        analysis_context: build_analysis_context
      }
    end
  end

  def fetch_behavior_metrics
    # Aggregate metrics from multiple sources with performance optimization
    metrics = {}

    # Login behavior metrics
    if @user.respond_to?(:sign_in_count) && @user.sign_in_count > 0
      metrics[:login_frequency] = calculate_login_frequency
      metrics[:login_timing] = analyze_login_timing
    end

    # Transaction/purchase behavior metrics
    if @user.respond_to?(:orders) && @user.orders.exists?
      metrics[:purchase_behavior] = analyze_purchase_behavior
      metrics[:order_values] = analyze_order_values
    end

    # Activity velocity metrics
    metrics[:activity_velocity] = calculate_activity_velocity

    # Device and location metrics
    metrics[:device_patterns] = analyze_device_patterns
    metrics[:location_patterns] = analyze_location_patterns

    metrics
  end

  def fetch_historical_patterns
    cache_key = "user_historical_patterns:#{@user.id}"

    @cache_service.fetch(cache_key, ttl: 3600) do # 1 hour cache
      @repository.get_historical_patterns(@user, 90.days.ago)
    end
  end

  def fetch_time_series_data
    # Fetch time-series data for temporal analysis
    @repository.get_time_series_data(@user, 30.days.ago)
  end

  def build_analysis_context
    {
      analysis_id: SecureRandom.uuid,
      timestamp: Time.current,
      ip_address: @user.current_sign_in_ip,
      user_agent: @user.current_user_agent,
      session_id: @user.current_session_id,
      risk_tier: @user.risk_tier,
      account_age_days: ((Time.current - @user.created_at) / 86400).to_i
    }
  end

  def execute_detection_strategies(behavior_data)
    # Parallel execution of detection strategies for optimal performance
    strategies = initialize_detection_strategies

    ParallelExecutionService.execute(strategies) do |strategy|
      strategy.detect_anomalies(behavior_data)
    end
  end

  def initialize_detection_strategies
    [
      AnomalyDetection::StatisticalDeviationStrategy.new,
      AnomalyDetection::TemporalAnomalyStrategy.new,
      # Additional strategies can be easily added here
      # AnomalyDetection::SpatialAnomalyStrategy.new,
      # AnomalyDetection::VelocityAnomalyStrategy.new,
    ]
  end

  def aggregate_detection_results(detection_results)
    # Advanced ensemble learning approach for result aggregation
    ensemble_aggregator = DetectionResultAggregator.new(detection_results)

    {
      anomalous: ensemble_aggregator.anomalous?,
      confidence_score: ensemble_aggregator.overall_confidence,
      anomaly_details: ensemble_aggregator.anomaly_details,
      strategy_results: detection_results,
      analysis_metadata: build_analysis_metadata,
      performance_metrics: calculate_performance_metrics,
      recommendations: generate_recommendations(ensemble_aggregator)
    }
  end

  def persist_behavioral_patterns(analysis_result)
    # Create behavioral pattern records for anomalous activities
    analysis_result[:anomaly_details].each do |anomaly|
      @repository.create_from_anomaly(@user, anomaly)
    end
  end

  def publish_analysis_events(analysis_result)
    # Publish domain events for event sourcing and integration
    event = BehavioralAnalysisCompletedEvent.new(
      user_id: @user.id,
      analysis_id: @options[:analysis_id],
      anomalous: analysis_result[:anomalous],
      confidence_score: analysis_result[:confidence_score],
      timestamp: Time.current,
      strategy_count: analysis_result[:strategy_results].count
    )

    @event_publisher.publish(event)
  end

  def calculate_pattern_statistics
    patterns = @repository.find_by_user(@user, @time_range.ago..Time.current)

    {
      total_patterns: patterns.count,
      anomalous_patterns: patterns.anomalous.count,
      pattern_types: group_patterns_by_type(patterns),
      average_confidence: calculate_average_confidence(patterns),
      trend_analysis: calculate_trend_analysis(patterns),
      risk_assessment: assess_behavioral_risk(patterns)
    }
  end

  def group_patterns_by_type(patterns)
    patterns.group_by(&:pattern_type).transform_values(&:count)
  end

  def calculate_average_confidence(patterns)
    return 0.0 if patterns.empty?

    confidences = patterns.map(&:confidence_level).compact
    return 0.0 if confidences.empty?

    confidences.sum / confidences.count
  end

  def calculate_trend_analysis(patterns)
    # Analyze patterns for trends and changes over time
    daily_counts = patterns.group_by { |p| p.detected_at.to_date }
                          .transform_values(&:count)
                          .sort_by { |date, _| date }

    # Calculate trend direction and magnitude
    if daily_counts.count >= 7
      recent_avg = daily_counts.last(7).sum { |_, count| count } / 7.0
      previous_avg = daily_counts.first(7).sum { |_, count| count } / 7.0

      trend_direction = recent_avg > previous_avg ? :increasing : :decreasing
      trend_magnitude = ((recent_avg - previous_avg) / previous_avg).abs

      {
        direction: trend_direction,
        magnitude: trend_magnitude,
        recent_average: recent_avg,
        previous_average: previous_avg
      }
    else
      {
        direction: :insufficient_data,
        magnitude: 0.0
      }
    end
  end

  def assess_behavioral_risk(patterns)
    return :unknown if patterns.empty?

    # Multi-factor risk assessment
    anomalous_ratio = patterns.anomalous.count.to_f / patterns.count
    recent_anomalies = patterns.recent.anomalous.count
    avg_confidence = calculate_average_confidence(patterns.anomalous)

    risk_score = (anomalous_ratio * 40) + (recent_anomalies * 10) + (avg_confidence * 30)

    case risk_score
    when 0..30 then :low
    when 31..60 then :medium
    when 61..85 then :high
    else :critical
    end
  end

  def generate_recommendations(aggregator)
    # Generate actionable recommendations based on analysis results
    recommendations = []

    if aggregator.anomalous?
      recommendations << {
        type: :immediate_action,
        priority: :high,
        message: "Anomalous behavior detected - manual review recommended",
        actions: [:flag_for_review, :notify_security_team]
      }
    end

    if aggregator.overall_confidence > 0.8
      recommendations << {
        type: :monitoring,
        priority: :medium,
        message: "High confidence anomaly - enhanced monitoring recommended",
        actions: [:increase_monitoring_frequency, :enable_detailed_logging]
      }
    end

    recommendations
  end

  def execute_with_circuit_breaker
    @circuit_breaker.execute do
      yield
    end
  rescue CircuitBreaker::OpenError => e
    # Circuit breaker is open - return fallback result
    Rails.logger.warn("Circuit breaker open for behavioral analysis: #{e.message}")

    failure('Service temporarily unavailable - circuit breaker protection active')
  end

  def handle_analysis_error(error)
    # Comprehensive error handling with context
    ErrorLogger.log(
      service: :behavioral_analysis,
      error: error.class.name,
      message: error.message,
      user_id: @user&.id,
      options: @options,
      execution_time_ms: calculate_execution_time_ms
    )

    failure("Analysis failed: #{error.message}")
  end

  def insufficient_data?(behavior_data)
    # Check if we have sufficient data for meaningful analysis
    metrics = behavior_data[:behavior_metrics]
    historical = behavior_data[:historical_patterns]

    metrics.empty? || (historical.is_a?(Hash) && historical.values.all?(&:empty?))
  end

  def normalized_filters
    # Normalize and validate filter parameters
    @filters.transform_keys(&:to_sym).slice(
      :pattern_type, :anomalous, :date_range, :confidence_threshold
    )
  end

  def generate_cache_key(type, parameters)
    # Generate consistent cache keys for different query types
    parameter_string = parameters.is_a?(Hash) ? parameters.sort.to_json : parameters.to_s
    digest = Digest::SHA256.new.update("#{type}:#{@user.id}:#{parameter_string}")
    "behavioral_analysis:#{digest.hexdigest[0..16]}"
  end

  def calculate_execution_time_ms
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ((end_time - @start_time) * 1000).round(2)
  end

  def calculate_performance_metrics
    {
      execution_time_ms: calculate_execution_time_ms,
      memory_usage_mb: estimate_memory_usage,
      cache_hit_rate: calculate_cache_hit_rate,
      circuit_breaker_trips: @circuit_breaker.trip_count
    }
  end

  def estimate_memory_usage
    # Estimate memory usage for monitoring and optimization
    base_memory = 10 # MB
    data_complexity = [@user.orders.count, @user.fraud_checks.count].max

    base_memory + (data_complexity * 0.1).round(1)
  end

  def calculate_cache_hit_rate
    # Calculate cache performance for optimization insights
    @cache_service.hit_rate(@user.id) rescue 0.0
  end

  def build_analysis_metadata
    {
      analysis_id: @options[:analysis_id] || SecureRandom.uuid,
      timestamp: Time.current,
      user_id: @user.id,
      sensitivity_level: @options[:sensitivity_level],
      strategies_executed: initialize_detection_strategies.count,
      data_sources: [:behavior_metrics, :historical_patterns, :time_series_data],
      algorithm_versions: extract_algorithm_versions
    }
  end

  def extract_algorithm_versions
    strategies = initialize_detection_strategies
    strategies.map { |strategy| "#{strategy.algorithm_name}:#{strategy.algorithm_version}" }
  end

  def default_options
    {
      sensitivity_level: :moderate,
      parallel_execution: true,
      cache_results: true,
      publish_events: true,
      include_performance_metrics: false
    }
  end

  def fallback_data
    # Fallback data when external services are unavailable
    {
      user: @user,
      behavior_metrics: {},
      historical_patterns: {},
      time_series_data: [],
      current_time: Time.current,
      sensitivity_level: :low, # Conservative fallback
      analysis_context: {}
    }
  end
end

# ==================== SUPPORTING SERVICE CLASSES ====================

# Detection Result Aggregator for ensemble learning
class DetectionResultAggregator
  def initialize(detection_results)
    @results = detection_results
    @anomalies = []
    @confidence_scores = []

    aggregate_results
  end

  def anomalous?
    @anomalies.any? || weighted_confidence_score > 0.7
  end

  def overall_confidence
    weighted_confidence_score
  end

  def anomaly_details
    @anomalies
  end

  private

  def aggregate_results
    @results.each do |result|
      next unless result[:anomalous]

      @anomalies.concat(result[:anomalies] || [])
      @confidence_scores.concat(result[:confidence_scores] || [result[:confidence_score]])
    end
  end

  def weighted_confidence_score
    return 0.0 if @confidence_scores.empty?

    # Weighted average with recency bias
    total_weight = 0.0
    weighted_sum = 0.0

    @confidence_scores.each_with_index do |confidence, index|
      # Recency bias - more recent results have higher weight
      weight = (index + 1).to_f / @confidence_scores.count
      weighted_sum += confidence * weight
      total_weight += weight
    end

    total_weight > 0 ? weighted_sum / total_weight : 0.0
  end
end

# Parallel Execution Service for performance optimization
class ParallelExecutionService
  def self.execute(strategies)
    # Execute strategies in parallel for optimal performance
    results = []

    if strategies.count > 1
      # Use parallel processing for multiple strategies
      Parallel.map(strategies, in_threads: strategies.count) do |strategy|
        begin
          yield(strategy)
        rescue StandardError => e
          Rails.logger.error("Strategy execution failed: #{strategy.class.name} - #{e.message}")
          {
            anomalous: false,
            error: e.message,
            algorithm: strategy.algorithm_name,
            execution_time_ms: 0
          }
        end
      end
    else
      # Single strategy execution
      [yield(strategies.first)]
    end
  end
end

# Repository interface for data access abstraction
class BehavioralPatternRepository
  def find_by_user(user, filters = {})
    # Implementation would query the database
    # This is a placeholder for the actual implementation
    user.behavioral_patterns.where(filters)
  end

  def get_historical_patterns(user, since_date)
    # Implementation would aggregate historical pattern data
    # This is a placeholder for the actual implementation
    {}
  end

  def get_time_series_data(user, since_date)
    # Implementation would fetch time-series behavior data
    # This is a placeholder for the actual implementation
    []
  end

  def create_from_anomaly(user, anomaly_data)
    # Implementation would create behavioral pattern record
    # This is a placeholder for the actual implementation
    user.behavioral_patterns.create!(
      pattern_type: anomaly_data[:pattern_type] || :general,
      anomalous: true,
      pattern_data: anomaly_data,
      detected_at: Time.current
    )
  end
end

# Domain Events for Event Sourcing
class BehavioralAnalysisCompletedEvent
  attr_reader :user_id, :analysis_id, :anomalous, :confidence_score, :timestamp, :strategy_count

  def initialize(user_id:, analysis_id:, anomalous:, confidence_score:, timestamp:, strategy_count:)
    @user_id = user_id
    @analysis_id = analysis_id
    @anomalous = anomalous
    @confidence_score = confidence_score
    @timestamp = timestamp
    @strategy_count = strategy_count
  end

  def event_type
    :behavioral_analysis_completed
  end

  def to_h
    {
      event_type: event_type,
      user_id: user_id,
      analysis_id: analysis_id,
      anomalous: anomalous,
      confidence_score: confidence_score,
      timestamp: timestamp,
      strategy_count: strategy_count
    }
  end
end

class BehavioralPatternDetectedEvent
  attr_reader :pattern_id, :user_id, :pattern_type, :anomalous, :detected_at, :changes

  def initialize(pattern_id:, user_id:, pattern_type:, anomalous:, detected_at:, changes:)
    @pattern_id = pattern_id
    @user_id = user_id
    @pattern_type = pattern_type
    @anomalous = anomalous
    @detected_at = detected_at
    @changes = changes
  end

  def event_type
    :behavioral_pattern_detected
  end

  def to_h
    {
      event_type: event_type,
      pattern_id: pattern_id,
      user_id: user_id,
      pattern_type: pattern_type,
      anomalous: anomalous,
      detected_at: detected_at,
      changes: changes
    }
  end
end

# Service integration modules
module ServiceResultHelper
  def success(data = nil)
    { success: true, data: data }
  end

  def failure(message, details = nil)
    { success: false, error: message, details: details }
  end
end

# Performance monitoring integration
class PerformanceMetrics
  def self.record(metrics)
    # Record performance metrics for monitoring and optimization
    Rails.logger.info("Performance Metrics: #{metrics}") if Rails.logger

    # Could integrate with monitoring services like Datadog, New Relic, etc.
    MonitoringService.record(metrics) if defined?(MonitoringService)
  end
end

# Error logging integration
class ErrorLogger
  def self.log(context)
    Rails.logger.error("Service Error: #{context}") if Rails.logger

    # Could integrate with error tracking services like Sentry, Rollbar, etc.
    ErrorTrackingService.capture(context) if defined?(ErrorTrackingService)
  end
end

# Cache service integration
class CacheService
  def self.get(key)
    Rails.cache.read(key)
  end

  def self.set(key, value, ttl: 300)
    Rails.cache.write(key, value, expires_in: ttl.seconds)
  end

  def self.fetch(key, ttl: 300)
    Rails.cache.fetch(key, expires_in: ttl.seconds) do
      yield
    end
  end

  def self.hit_rate(user_id)
    # Placeholder for cache hit rate calculation
    0.85 # Mock 85% hit rate
  end
end

# Circuit breaker service integration
class CircuitBreakerService
  def initialize
    @trip_count = 0
  end

  def execute
    # Check if circuit breaker should allow execution
    unless circuit_open?
      begin
        result = yield
        record_success
        result
      rescue StandardError => e
        record_failure
        raise e
      end
    else
      raise CircuitBreaker::OpenError.new("Circuit breaker is open")
    end
  end

  def execute_with_fallback(fallback = nil)
    execute { yield }
  rescue CircuitBreaker::OpenError
    fallback
  end

  def trip_count
    @trip_count
  end

  private

  def circuit_open?
    @trip_count > 5 # Simple threshold - could be more sophisticated
  end

  def record_success
    @trip_count = [@trip_count - 1, 0].max # Decrease trip count on success
  end

  def record_failure
    @trip_count += 1
  end
end

# Event publisher for domain events
class EventPublisher
  def self.publish(event)
    # Publish domain event to event store
    Rails.logger.info("Publishing event: #{event.event_type} - #{event.to_h}") if Rails.logger

    # Could integrate with event sourcing systems like EventStore, Kafka, etc.
    EventStore.append(event) if defined?(EventStore)
  end
end