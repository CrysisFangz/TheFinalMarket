# frozen_string_literal: true

# Observability Service - Distributed Tracing and Metrics
#
# This service provides comprehensive observability capabilities including distributed
# tracing, metrics collection, structured logging, and performance monitoring. It
# integrates with industry-standard tools like OpenTelemetry, Prometheus, and ELK stack.
#
# Key Features:
# - Distributed tracing with correlation IDs
# - Structured logging with contextual information
# - Metrics collection and aggregation
# - Performance profiling and analysis
# - Real-time alerting and monitoring
# - Integration with external observability platforms
#
# @see OpenTelemetry
# @see Prometheus
class ObservabilityService
  include Singleton
  include Concurrent::Async

  # Initialize observability providers
  def initialize
    super()
    initialize_tracing
    initialize_metrics
    initialize_logging
    start_background_tasks
  end

  # Create distributed trace span
  # @param operation_name [String] name of the operation being traced
  # @param trace_id [String] optional existing trace ID
  # @return [OpenTelemetry::Span] active span
  def self.trace(operation_name, trace_id: nil)
    instance.create_span(operation_name, trace_id)
  end

  # Create child span from parent context
  # @param operation_name [String] name of the operation
  # @param parent_context [OpenTelemetry::Context] parent tracing context
  # @return [OpenTelemetry::Span] child span
  def self.trace_child(operation_name, parent_context)
    instance.create_child_span(operation_name, parent_context)
  end

  # Record metric with tags
  # @param name [String, Symbol] metric name
  # @param value [Numeric] metric value
  # @param tags [Hash] metric tags/labels
  # @param type [Symbol] metric type (:counter, :gauge, :histogram)
  def self.record_metric(name, value, tags: {}, type: :counter)
    instance.record_metric_sync(name, value, tags, type)
  end

  # Record structured event
  # @param event_name [String, Symbol] event name
  # @param payload [Hash] event data
  # @param level [Symbol] log level (:debug, :info, :warn, :error)
  def self.record_event(event_name, payload = {}, level: :info)
    instance.record_event_sync(event_name, payload, level)
  end

  # Add attribute to current span
  # @param key [String] attribute key
  # @param value [Object] attribute value
  def self.set_attribute(key, value)
    current_span = OpenTelemetry::Trace.current_span
    current_span.set_attribute(key, value) if current_span
  end

  # Record exception in current span
  # @param exception [Exception] exception to record
  def self.record_exception(exception)
    current_span = OpenTelemetry::Trace.current_span
    if current_span
      current_span.record_exception(exception)
      current_span.set_attribute('exception.type', exception.class.name)
      current_span.set_attribute('exception.message', exception.message)
    end
  end

  # Health check for observability services
  # @return [Boolean] true if all services are healthy
  def self.healthy?
    instance.healthy?
  end

  private

  # Initialize distributed tracing
  def initialize_tracing
    @tracer_provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    @tracer = @tracer_provider.tracer('channel_interaction_service')

    # Configure span processors
    span_processor = OpenTelemetry::SDK::Trace::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::TraceExporter.new(
        endpoint: ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] || 'http://localhost:4318/v1/traces'
      )
    )

    @tracer_provider.add_span_processor(span_processor)

    OpenTelemetry::SDK.configure(provider: @tracer_provider)
  end

  # Initialize metrics collection
  def initialize_metrics
    @meter_provider = OpenTelemetry::SDK::Metrics::MeterProvider.new
    @meter = @meter_provider.meter('channel_interaction_service')

    # Configure metrics exporter
    metrics_reader = OpenTelemetry::SDK::Metrics::PeriodicMetricReader.new(
      OpenTelemetry::Exporter::OTLP::MetricExporter.new(
        endpoint: ENV['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] || 'http://localhost:4318/v1/metrics'
      ),
      export_interval_milliseconds: 30000
    )

    @meter_provider.add_metric_reader(metrics_reader)
    OpenTelemetry::SDK::Metrics::SDK.configure(provider: @meter_provider)
  end

  # Initialize structured logging
  def initialize_logging
    @logger = SemanticLogger::Logger.new(self.class.name)

    # Configure log formatter
    formatter = SemanticLogger::Formatters::Json.new
    @logger.formatter = formatter

    # Configure log level
    @logger.level = ENV['LOG_LEVEL']&.to_sym || :info
  end

  # Start background monitoring tasks
  def start_background_tasks
    # Monitor performance metrics
    async.monitor_performance_metrics

    # Monitor error rates
    async.monitor_error_rates

    # Monitor resource usage
    async.monitor_resource_usage

    # Export traces and metrics
    async.export_telemetry_data
  end

  # Create new tracing span
  def create_span(operation_name, trace_id = nil)
    # Generate trace ID if not provided
    trace_id ||= generate_trace_id

    # Set trace context in thread local storage
    trace_context = OpenTelemetry::Trace::TraceContext.new(
      trace_id: trace_id,
      span_id: generate_span_id,
      trace_flags: OpenTelemetry::Trace::TraceFlags::DEFAULT
    )

    # Create span with context
    span = @tracer.start_span(
      operation_name,
      kind: :internal,
      trace_context: trace_context
    )

    # Set span attributes
    span.set_attribute('service.name', 'channel_interaction_service')
    span.set_attribute('service.version', '2.0.0')
    span.set_attribute('deployment.environment', ENV['RAILS_ENV'] || 'development')

    # Store current span in thread context
    OpenTelemetry::Trace.with_span(span) do
      yield span if block_given?
    end

    span
  end

  # Create child span from parent
  def create_child_span(operation_name, parent_context)
    span = @tracer.start_span(
      operation_name,
      kind: :internal,
      context: parent_context
    )

    OpenTelemetry::Trace.with_span(span) do
      yield span if block_given?
    end

    span
  end

  # Record metric synchronously
  def record_metric_sync(name, value, tags, type)
    with_observability('metric_recording') do |span|
      span.set_attribute('metric.name', name.to_s)
      span.set_attribute('metric.type', type.to_s)

      case type
      when :counter
        counter = @meter.create_counter(name.to_s)
        counter.add(value, attributes: tags)
      when :gauge
        gauge = @meter.create_gauge(name.to_s)
        gauge.record(value, attributes: tags)
      when :histogram
        histogram = @meter.create_histogram(name.to_s)
        histogram.record(value, attributes: tags)
      end

      # Also record in Rails cache for fallback queries
      record_metric_in_cache(name, value, tags)

      span.set_attribute('metric.recorded', true)
    end
  end

  # Record event synchronously
  def record_event_sync(event_name, payload, level)
    with_observability('event_recording') do |span|
      span.set_attribute('event.name', event_name.to_s)
      span.set_attribute('event.level', level.to_s)

      # Prepare structured log data
      log_data = {
        event: event_name,
        timestamp: Time.current,
        correlation_id: Thread.current[:correlation_id],
        **payload
      }

      # Log at appropriate level
      case level
      when :debug
        @logger.debug(event_name, **log_data)
      when :info
        @logger.info(event_name, **log_data)
      when :warn
        @logger.warn(event_name, **log_data)
      when :error
        @logger.error(event_name, **log_data)
      end

      # Record as span event
      span.add_event(event_name.to_s, attributes: payload)

      span.set_attribute('event.recorded', true)
    end
  end

  # Record metric in cache for fallback queries
  def record_metric_in_cache(name, value, tags)
    cache_key = "metric:#{name}:#{Time.current.to_i / 60}" # Per-minute bucket

    current_metrics = AdaptiveCacheService.fetch(cache_key, ttl: 1.hour) do
      { count: 0, sum: 0, min: nil, max: nil }
    end

    updated_metrics = {
      count: current_metrics[:count] + 1,
      sum: current_metrics[:sum] + value,
      min: [current_metrics[:min] || value, value].min,
      max: [current_metrics[:max] || value, value].max,
      avg: (current_metrics[:sum] + value) / (current_metrics[:count] + 1),
      last_updated: Time.current
    }

    AdaptiveCacheService.fetch(cache_key, ttl: 1.hour) { updated_metrics }
  end

  # Monitor performance metrics
  def monitor_performance_metrics
    loop do
      begin
        # Record Ruby GC metrics
        record_gc_metrics

        # Record memory usage metrics
        record_memory_metrics

        # Record CPU usage metrics
        record_cpu_metrics

        # Record active record metrics
        record_active_record_metrics

        sleep(30.seconds)
      rescue StandardError => e
        record_event_sync('performance_monitoring_error', {
          error: e.message,
          backtrace: e.backtrace.first
        }, :error)
        sleep(60.seconds)
      end
    end
  end

  # Monitor error rates and patterns
  def monitor_error_rates
    loop do
      begin
        # Get error metrics from last hour
        error_cache_key = "metric:errors:#{Time.current.to_i / 3600}"
        error_metrics = AdaptiveCacheService.fetch(error_cache_key) { { count: 0 } }

        # Alert if error rate is too high
        if error_metrics[:count] > 100 # More than 100 errors per hour
          record_event_sync('high_error_rate_detected', {
            error_count: error_metrics[:count],
            threshold: 100,
            time_window: '1_hour'
          }, :warn)
        end

        sleep(5.minutes)
      rescue StandardError => e
        record_event_sync('error_rate_monitoring_error', {
          error: e.message
        }, :error)
        sleep(5.minutes)
      end
    end
  end

  # Monitor system resource usage
  def monitor_resource_usage
    loop do
      begin
        # Record database connection pool usage
        record_database_metrics

        # Record Redis connection usage
        record_redis_metrics

        # Record Sidekiq queue metrics
        record_sidekiq_metrics

        sleep(60.seconds)
      rescue StandardError => e
        record_event_sync('resource_monitoring_error', {
          error: e.message
        }, :error)
        sleep(120.seconds)
      end
    end
  end

  # Export telemetry data to external systems
  def export_telemetry_data
    loop do
      begin
        # Force flush of traces and metrics
        @tracer_provider.force_flush
        @meter_provider.force_flush

        sleep(60.seconds)
      rescue StandardError => e
        record_event_sync('telemetry_export_error', {
          error: e.message
        }, :error)
        sleep(120.seconds)
      end
    end
  end

  # Generate unique trace ID
  def generate_trace_id
    "trace_#{SecureRandom.uuid}"
  end

  # Generate unique span ID
  def generate_span_id
    SecureRandom.hex(8)
  end

  # Record garbage collection metrics
  def record_gc_metrics
    gc_stats = GC.stat

    record_metric_sync('gc.collections', gc_stats[:count], { type: 'minor' }, :counter)
    record_metric_sync('gc.major_collections', gc_stats[:major_gc_count], {}, :counter)
    record_metric_sync('gc.heap_live_slots', gc_stats[:heap_live_slots], {}, :gauge)
    record_metric_sync('gc.heap_free_slots', gc_stats[:heap_free_slots], {}, :gauge)
  end

  # Record memory usage metrics
  def record_memory_metrics
    if defined?(GetProcessMem)
      memory_kb = GetProcessMem.new.bytes.to_i / 1024

      record_metric_sync('process.memory_usage_kb', memory_kb, {}, :gauge)
      record_metric_sync('process.memory_usage_mb', memory_kb / 1024, {}, :gauge)
    end
  end

  # Record CPU usage metrics
  def record_cpu_metrics
    if defined?(GetProcessMem)
      cpu_usage = `ps -o pcpu= -p #{Process.pid}`.strip.to_f rescue 0.0

      record_metric_sync('process.cpu_usage_percent', cpu_usage, {}, :gauge)
    end
  end

  # Record ActiveRecord metrics
  def record_active_record_metrics
    if defined?(ActiveRecord) && ActiveRecord::Base.connected?
      connection_pool = ActiveRecord::Base.connection_pool

      record_metric_sync('db.connections.active', connection_pool.connections.size, {}, :gauge)
      record_metric_sync('db.connections.idle', connection_pool.size - connection_pool.connections.size, {}, :gauge)
    end
  end

  # Record database-specific metrics
  def record_database_metrics
    return unless defined?(ActiveRecord) && ActiveRecord::Base.connected?

    connection_pool = ActiveRecord::Base.connection_pool

    record_metric_sync('db.connection_pool.size', connection_pool.size, {}, :gauge)
    record_metric_sync('db.connection_pool.available', connection_pool.available, {}, :gauge)
  end

  # Record Redis metrics
  def record_redis_metrics
    return unless defined?(Redis)

    begin
      redis_info = Redis.current.info rescue {}

      record_metric_sync('redis.connected_clients', redis_info['connected_clients'].to_i, {}, :gauge)
      record_metric_sync('redis.used_memory_mb', redis_info['used_memory'].to_i / 1024 / 1024, {}, :gauge)
      record_metric_sync('redis.keyspace_hits', redis_info['keyspace_hits'].to_i, {}, :counter)
      record_metric_sync('redis.keyspace_misses', redis_info['keyspace_misses'].to_i, {}, :counter)
    rescue StandardError => e
      record_event_sync('redis_metrics_error', { error: e.message }, :error)
    end
  end

  # Record Sidekiq metrics
  def record_sidekiq_metrics
    return unless defined?(Sidekiq)

    begin
      # Get queue metrics
      Sidekiq::Queue.all.each do |queue|
        record_metric_sync('sidekiq.queue.size', queue.size, { queue: queue.name }, :gauge)
        record_metric_sync('sidekiq.queue.latency', queue.latency, { queue: queue.name }, :gauge)
      end

      # Get worker metrics
      record_metric_sync('sidekiq.workers.active', Sidekiq::Workers.new.size, {}, :gauge)
      record_metric_sync('sidekiq.processed_jobs', Sidekiq::Stats.new.processed, {}, :counter)
      record_metric_sync('sidekiq.failed_jobs', Sidekiq::Stats.new.failed, {}, :counter)
    rescue StandardError => e
      record_event_sync('sidekiq_metrics_error', { error: e.message }, :error)
    end
  end

  # Health check implementation
  def healthy?
    @tracer_provider&.ready? && @meter_provider&.ready? && @logger&.ready? rescue false
  end

  # Observability wrapper for internal operations
  def with_observability(operation_name)
    create_span(operation_name) do |span|
      yield span
    end
  end
end