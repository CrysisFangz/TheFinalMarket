# frozen_string_literal: true

# =============================================================================
# TelemetryService::Comprehensive - Enterprise Observability Framework
# =============================================================================
# Provides comprehensive observability with hyperscale metrics collection,
# distributed tracing, and real-time alerting for mission-critical systems
#
# Architecture: Distributed Tracing + Metrics Pipeline + Alerting Engine
# Performance: O(1) metric recording, sub-millisecond tracing overhead
# Scalability: Hierarchical metric aggregation with adaptive sampling
# Resilience: Fault-tolerant telemetry with local buffering and batching
# =============================================================================

module TelemetryService
  class Comprehensive
    include Singleton
    include Concerns::CircuitBreaker
    include Concerns::AdaptiveSampling

    # ==================== DEPENDENCY INJECTION ====================
    attr_accessor :metrics_backend, :tracing_backend, :logging_backend, :alerting_backend

    # ==================== CONSTANTS (IMMUTABLE CONFIGURATION) ====================
    METRICS_BATCH_SIZE = 1000
    METRICS_FLUSH_INTERVAL = 5.seconds
    TRACING_SAMPLE_RATE = 0.1 # 10% sampling for production
    MAX_METRIC_VALUE = 1_000_000_000
    METRIC_RETENTION_HOURS = 720 # 30 days
    ALERT_COOLDOWN_PERIOD = 5.minutes

    # ==================== METRIC COLLECTION ====================

    def increment_counter(metric_name, value = 1, tags: {}, timestamp: Time.current)
      with_error_handling("increment_counter") do
        validate_metric_name!(metric_name)
        validate_metric_value!(value)

        metric_key = build_metric_key(metric_name, tags)

        # Adaptive sampling for high-frequency metrics
        if should_sample?(metric_name, tags)
          # Local buffering for performance
          buffered_metrics[metric_key] ||= Concurrent::AtomicFixnum.new(0)
          buffered_metrics[metric_key].increment(value)

          # Async batch processing
          schedule_metrics_flush if should_flush_metrics?
        end

        record_metric_event(metric_name, :counter, value, tags, timestamp)
      end
    end

    def record_histogram(metric_name, value, tags: {}, timestamp: Time.current)
      with_error_handling("record_histogram") do
        validate_metric_name!(metric_name)
        validate_metric_value!(value)

        metric_key = build_metric_key(metric_name, tags)

        if should_sample?(metric_name, tags)
          # Thread-safe histogram recording
          histogram_buffer[metric_key] ||= Concurrent::Array.new
          histogram_buffer[metric_key] << {
            value: value,
            timestamp: timestamp,
            tags: tags
          }

          schedule_histogram_flush if histogram_buffer[metric_key].size >= histogram_batch_size
        end

        record_metric_event(metric_name, :histogram, value, tags, timestamp)
      end
    end

    def record_gauge(metric_name, value, tags: {}, timestamp: Time.current)
      with_error_handling("record_gauge") do
        validate_metric_name!(metric_name)
        validate_metric_value!(value)

        metric_key = build_metric_key(metric_name, tags)

        if should_sample?(metric_name, tags)
          # Gauges are recorded immediately for real-time monitoring
          metrics_backend.record_gauge(metric_key, value, tags, timestamp)
        end

        record_metric_event(metric_name, :gauge, value, tags, timestamp)
      end
    end

    def record_latency(operation_name, duration_ms, tags: {}, timestamp: Time.current)
      record_histogram(
        "operation_latency",
        duration_ms,
        tags: tags.merge(operation: operation_name),
        timestamp: timestamp
      )
    end

    def record_operation_duration(operation_name, start_time, tags: {})
      duration_ms = (Time.current - start_time) * 1000
      record_latency(operation_name, duration_ms, tags: tags)
    end

    # ==================== DISTRIBUTED TRACING ====================

    def start_trace(operation_name, trace_id: nil, parent_span_id: nil, tags: {})
      with_error_handling("start_trace") do
        trace_id ||= generate_trace_id
        span_id = generate_span_id

        span = tracing_backend.create_span(
          trace_id: trace_id,
          span_id: span_id,
          parent_span_id: parent_span_id,
          operation_name: operation_name,
          start_time: Time.current,
          tags: tags
        )

        # Store active span in thread-local storage
        Thread.current[:active_span] = span

        record_trace_event(:span_started, operation_name, span)

        span
      end
    end

    def finish_trace(span = nil, status: :success, error: nil)
      with_error_handling("finish_trace") do
        span ||= Thread.current[:active_span]
        return unless span

        span.finish_time = Time.current
        span.status = status
        span.error = error if error

        # Record span in tracing backend
        tracing_backend.record_span(span)

        # Clear thread-local storage
        Thread.current[:active_span] = nil

        record_trace_event(:span_finished, span.operation_name, span)

        span
      end
    end

    def add_trace_tag(key, value)
      span = Thread.current[:active_span]
      return unless span

      span.tags[key] = value
    end

    def record_trace_event(event_type, operation_name, span)
      # Record trace metadata for analysis
      trace_metadata[span&.trace_id] ||= {}
      trace_metadata[span&.trace_id][event_type] = {
        operation_name: operation_name,
        timestamp: Time.current,
        span_id: span&.span_id
      }
    end

    # ==================== STRUCTURED LOGGING ====================

    def log_event(level, message, tags: {}, error: nil, **context)
      with_error_handling("log_event") do
        log_entry = build_log_entry(level, message, tags, error, context)

        # Async logging with buffering
        log_buffer << log_entry

        # Immediate logging for errors and warnings
        if level == :error || level == :warn
          logging_backend.log_immediately(log_entry)
        end

        schedule_log_flush if should_flush_logs?
      end
    end

    def alert_error(error, context: {}, severity: :medium)
      with_error_handling("alert_error") do
        return if in_alert_cooldown?(error, context)

        alert = build_alert(error, context, severity)

        # Record error metrics
        increment_counter("errors_total",
          tags: {
            error_type: error.class.name,
            severity: severity,
            **context.transform_keys(&:to_s)
          }
        )

        # Send alert
        alerting_backend.send_alert(alert)

        # Set cooldown to prevent spam
        set_alert_cooldown(error, context)

        record_alert_event(alert)
      end
    end

    # ==================== HEALTH MONITORING ====================

    def record_health_check(service_name, status, response_time_ms = nil, tags: {})
      with_error_handling("record_health_check") do
        health_metric = {
          service: service_name,
          status: status,
          timestamp: Time.current,
          response_time_ms: response_time_ms,
          tags: tags
        }

        health_checks_buffer << health_metric

        # Update service health gauge
        record_gauge(
          "service_health",
          status == :healthy ? 1 : 0,
          tags: { service: service_name }.merge(tags)
        )

        schedule_health_check_flush if should_flush_health_checks?
      end
    end

    def record_circuit_breaker_event(circuit_name, event_type, tags: {})
      increment_counter("circuit_breaker_events",
        tags: {
          circuit: circuit_name,
          event_type: event_type
        }.merge(tags)
      )
    end

    # ==================== PERFORMANCE PROFILING ====================

    def profile_operation(operation_name, tags: {})
      start_memory = get_memory_usage
      start_cpu = get_cpu_usage
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      result = nil

      begin
        result = yield
      ensure
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end_memory = get_memory_usage
        end_cpu = get_cpu_usage

        duration_ms = (end_time - start_time) * 1000
        memory_delta_mb = (end_memory - start_memory) / 1024.0 / 1024.0
        cpu_delta = end_cpu - start_cpu

        record_histogram("operation_duration", duration_ms,
          tags: { operation: operation_name }.merge(tags))
        record_gauge("operation_memory_delta", memory_delta_mb,
          tags: { operation: operation_name }.merge(tags))
        record_gauge("operation_cpu_delta", cpu_delta,
          tags: { operation: operation_name }.merge(tags))
      end

      result
    end

    # ==================== METRIC AGGREGATION & ANALYSIS ====================

    def get_metric_summary(metric_name, time_range: 1.hour, tags: {})
      with_circuit_breaker("get_metric_summary") do
        metrics_backend.get_metric_summary(
          metric_name: metric_name,
          time_range: time_range,
          tags: tags
        )
      end
    end

    def get_top_operations(limit: 10, time_range: 1.hour)
      with_circuit_breaker("get_top_operations") do
        metrics_backend.get_top_operations(
          limit: limit,
          time_range: time_range
        )
      end
    end

    def get_error_rate(time_range: 1.hour, tags: {})
      with_circuit_breaker("get_error_rate") do
        metrics_backend.get_error_rate(
          time_range: time_range,
          tags: tags
        )
      end
    end

    def get_p95_latency(operation_name, time_range: 1.hour, tags: {})
      with_circuit_breaker("get_p95_latency") do
        metrics_backend.get_percentile_latency(
          operation_name: operation_name,
          percentile: 95,
          time_range: time_range,
          tags: tags
        )
      end
    end

    # ==================== PRIVATE METHODS ====================

    private

    # ==================== VALIDATION ====================
    def validate_metric_name!(name)
      unless name.is_a?(String) && name.match?(/\A[a-z_][a-z0-9_]*\z/)
        raise ValidationError, "Invalid metric name format"
      end

      if name.length > 100
        raise ValidationError, "Metric name too long"
      end
    end

    def validate_metric_value!(value)
      unless value.is_a?(Numeric) && value.finite? && value >= 0
        raise ValidationError, "Invalid metric value"
      end

      if value > MAX_METRIC_VALUE
        raise ValidationError, "Metric value exceeds maximum"
      end
    end

    # ==================== METRIC KEY GENERATION ====================
    def build_metric_key(metric_name, tags)
      tag_string = tags.sort.map { |k, v| "#{k}=#{v}" }.join(",")
      [metric_name, tag_string].compact.join("|")
    end

    # ==================== SAMPLING LOGIC ====================
    def should_sample?(metric_name, tags)
      # Adaptive sampling based on metric frequency and importance
      sample_rate = calculate_adaptive_sample_rate(metric_name, tags)
      rand < sample_rate
    end

    def calculate_adaptive_sample_rate(metric_name, tags)
      # High-frequency metrics get lower sample rates
      case metric_name
      when /_counter$/, /_total$/
        0.01 # 1% for counters
      when /_latency$/, /_duration$/
        0.1  # 10% for latency metrics
      when /_error$/
        1.0  # 100% for errors
      else
        0.05 # 5% default
      end
    end

    # ==================== BUFFER MANAGEMENT ====================
    def buffered_metrics
      @buffered_metrics ||= Concurrent::Map.new
    end

    def histogram_buffer
      @histogram_buffer ||= Concurrent::Map.new
    end

    def log_buffer
      @log_buffer ||= Concurrent::Array.new
    end

    def health_checks_buffer
      @health_checks_buffer ||= Concurrent::Array.new
    end

    def trace_metadata
      @trace_metadata ||= Concurrent::Map.new
    end

    # ==================== FLUSHING LOGIC ====================
    def should_flush_metrics?
      buffered_metrics.size >= METRICS_BATCH_SIZE
    end

    def should_flush_logs?
      log_buffer.size >= 1000
    end

    def should_flush_health_checks?
      health_checks_buffer.size >= 100
    end

    def schedule_metrics_flush
      return if @metrics_flush_scheduled

      @metrics_flush_scheduled = true
      Concurrent::ScheduledTask.execute(METRICS_FLUSH_INTERVAL.from_now) do
        flush_metrics_buffer
        @metrics_flush_scheduled = false
      end
    end

    def schedule_histogram_flush
      Concurrent::ScheduledTask.execute(1.second.from_now) do
        flush_histogram_buffer
      end
    end

    def schedule_log_flush
      return if @log_flush_scheduled

      @log_flush_scheduled = true
      Concurrent::ScheduledTask.execute(2.seconds.from_now) do
        flush_log_buffer
        @log_flush_scheduled = false
      end
    end

    def schedule_health_check_flush
      return if @health_checks_flush_scheduled

      @health_checks_flush_scheduled = true
      Concurrent::ScheduledTask.execute(10.seconds.from_now) do
        flush_health_checks_buffer
        @health_checks_flush_scheduled = false
      end
    end

    # ==================== BUFFER FLUSHING ====================
    def flush_metrics_buffer
      return if buffered_metrics.empty?

      metrics_to_flush = {}
      buffered_metrics.each_pair do |key, atomic_value|
        metrics_to_flush[key] = atomic_value.value
        atomic_value.value = 0
      end

      metrics_backend.record_batch_counters(metrics_to_flush)

      record_telemetry_event(:metrics_flushed, metrics_to_flush.size)
    end

    def flush_histogram_buffer
      return if histogram_buffer.empty?

      histograms_to_flush = {}
      histogram_buffer.each_pair do |key, values|
        histograms_to_flush[key] = values.dup
        values.clear
      end

      metrics_backend.record_batch_histograms(histograms_to_flush)

      record_telemetry_event(:histograms_flushed, histograms_to_flush.size)
    end

    def flush_log_buffer
      return if log_buffer.empty?

      logs_to_flush = log_buffer.dup
      log_buffer.clear

      logging_backend.record_batch_logs(logs_to_flush)

      record_telemetry_event(:logs_flushed, logs_to_flush.size)
    end

    def flush_health_checks_buffer
      return if health_checks_buffer.empty?

      checks_to_flush = health_checks_buffer.dup
      health_checks_buffer.clear

      metrics_backend.record_batch_health_checks(checks_to_flush)

      record_telemetry_event(:health_checks_flushed, checks_to_flush.size)
    end

    # ==================== LOG ENTRY CONSTRUCTION ====================
    def build_log_entry(level, message, tags, error, context)
      {
        timestamp: Time.current,
        level: level,
        message: message,
        tags: tags,
        error: error_details(error),
        context: context,
        trace_id: Thread.current[:active_span]&.trace_id,
        span_id: Thread.current[:active_span]&.span_id,
        thread_id: Thread.current.object_id,
        process_id: Process.pid,
        hostname: Socket.gethostname
      }
    end

    def error_details(error)
      return nil unless error

      {
        class: error.class.name,
        message: error.message,
        backtrace: error.backtrace&.first(10) # Limit backtrace size
      }
    end

    # ==================== ALERT MANAGEMENT ====================
    def in_alert_cooldown?(error, context)
      cooldown_key = "alert_cooldown:#{error.class.name}:#{context.hash}"
      cooldown_until = alert_cooldown_cache.get(cooldown_key)

      return false unless cooldown_until
      Time.current < cooldown_until
    end

    def set_alert_cooldown(error, context)
      cooldown_key = "alert_cooldown:#{error.class.name}:#{context.hash}"
      alert_cooldown_cache.set(
        cooldown_key,
        Time.current + ALERT_COOLDOWN_PERIOD,
        ttl: ALERT_COOLDOWN_PERIOD
      )
    end

    def build_alert(error, context, severity)
      {
        id: generate_alert_id,
        timestamp: Time.current,
        severity: severity,
        error_class: error.class.name,
        error_message: error.message,
        context: context,
        trace_id: Thread.current[:active_span]&.trace_id,
        stack_trace: error.backtrace&.first(20),
        environment: Rails.env,
        hostname: Socket.gethostname,
        service_name: "conversation_service"
      }
    end

    def alert_cooldown_cache
      @alert_cooldown_cache ||= CacheStore::RedisBacked.instance
    end

    # ==================== SYSTEM METRICS ====================
    def get_memory_usage
      `ps -o rss= -p #{Process.pid}`.to_i * 1024 # Convert KB to bytes
    end

    def get_cpu_usage
      # This would typically use a more sophisticated CPU monitoring approach
      # For now, return a placeholder
      0.0
    end

    # ==================== ID GENERATION ====================
    def generate_trace_id
      SecureRandom.hex(16)
    end

    def generate_span_id
      SecureRandom.hex(8)
    end

    def generate_alert_id
      "alert_#{SecureRandom.hex(8)}"
    end

    # ==================== ERROR HANDLING ====================
    def with_error_handling(operation)
      yield
    rescue => e
      # Log telemetry errors without raising to avoid cascading failures
      log_event(:error, "Telemetry operation failed",
        error: e,
        operation: operation,
        tags: { telemetry_error: true }
      )
    end

    def record_telemetry_event(event_type, details)
      log_event(:info, "Telemetry event: #{event_type}",
        telemetry_event: true,
        event_type: event_type,
        details: details
      )
    end

    # ==================== BATCH SIZE CONFIGURATION ====================
    def histogram_batch_size
      @histogram_batch_size ||= calculate_optimal_histogram_batch_size
    end

    def calculate_optimal_histogram_batch_size
      # Adaptive batch sizing based on system performance
      base_size = 100

      # Adjust based on available memory and CPU
      memory_mb = `ps -o rss= -p #{Process.pid}`.to_i / 1024
      if memory_mb > 1000 # More than 1GB
        base_size * 2
      elsif memory_mb < 100 # Less than 100MB
        base_size / 2
      else
        base_size
      end
    end

    # ==================== DEPENDENCY CONFIGURATION ====================

    def configure_dependencies(
      metrics_backend: nil,
      tracing_backend: nil,
      logging_backend: nil,
      alerting_backend: nil
    )
      self.metrics_backend = metrics_backend || MetricsBackend::Datadog.instance
      self.tracing_backend = tracing_backend || TracingBackend::Jaeger.instance
      self.logging_backend = logging_backend || LoggingBackend::Structured.instance
      self.alerting_backend = alerting_backend || AlertingBackend::PagerDuty.instance
    end

    # ==================== INITIALIZATION ====================

    def initialize
      super
      configure_dependencies

      # Start background processors
      start_metrics_processor
      start_logging_processor
      start_health_check_processor

      # Initialize sampling algorithms
      initialize_adaptive_sampling
    end

    def start_metrics_processor
      @metrics_processor ||= Thread.new do
        loop do
          sleep METRICS_FLUSH_INTERVAL
          flush_metrics_buffer
        end
      end
    end

    def start_logging_processor
      @logging_processor ||= Thread.new do
        loop do
          sleep 2.seconds
          flush_log_buffer
        end
      end
    end

    def start_health_check_processor
      @health_checks_processor ||= Thread.new do
        loop do
          sleep 10.seconds
          flush_health_checks_buffer
        end
      end
    end

    # Auto-configure dependencies
    configure_dependencies
  end
end