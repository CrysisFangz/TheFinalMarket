# 🚀 COMPARELIST OBSERVABILITY CONCERN
# Enterprise Observability Implementation for Product Comparison Operations
#
# This concern provides comprehensive observability capabilities including
# distributed tracing, metrics collection, structured logging, and real-time
# monitoring for enterprise-grade operational visibility.

module CompareListObservability
  extend ActiveSupport::Concern

  # 🚀 DISTRIBUTED TRACING
  # Advanced distributed tracing with correlation IDs and span management

  def initialize_distributed_tracing
    @tracer = DistributedTracer.new(service_name: 'compare_list')
    @correlation_manager = CorrelationManager.new
    @span_manager = SpanManager.new
  end

  def execute_with_distributed_tracing(operation_name, &block)
    @tracer.trace(operation_name) do |span|
      span.set_tag('compare_list_id', id)
      span.set_tag('user_id', user_id)
      span.set_tag('operation', operation_name)

      with_correlation_id do
        execute_with_span_context(span, &block)
      end
    end
  end

  # 🚀 METRICS COLLECTION
  # Comprehensive metrics collection with dimensional analysis

  def collect_operation_metrics(operation_type, duration, metadata = {})
    metrics_collector.collect do |collector|
      collector.record_operation_duration(operation_type, duration)
      collector.record_operation_metadata(operation_type, metadata)
      collector.increment_operation_counter(operation_type)
      collector.record_resource_utilization(operation_type)
      collector.track_business_impact(operation_type, metadata)
    end
  end

  # 🚀 STRUCTURED LOGGING
  # Sophisticated structured logging with context propagation

  def execute_with_structured_logging(log_context = {}, &block)
    structured_logger.log do |logger|
      logger.with_context(log_context) do
        logger.info('Executing comparison operation', operation_context)
        execute_with_error_handling(&block)
        logger.info('Comparison operation completed', operation_context)
      end
    end
  end

  # 🚀 REAL-TIME MONITORING
  # Real-time monitoring with alerting and anomaly detection

  def initialize_real_time_monitoring
    @monitoring_client = MonitoringClient.new
    @alert_manager = AlertManager.new
    @anomaly_detector = AnomalyDetector.new
  end

  def monitor_operation_health(health_context = {})
    health_monitor.monitor do |monitor|
      monitor.check_response_times(self)
      monitor.verify_error_rates(self, health_context)
      monitor.validate_resource_usage(self)
      monitor.detect_anomalies(self)
      monitor.generate_health_reports(self)
    end
  end

  # 🚀 OBSERVABILITY ANALYTICS
  # Advanced observability analytics and insights generation

  def generate_observability_insights(insight_context = {})
    observability_analytics.generate do |analytics|
      analytics.analyze_performance_patterns(self)
      analytics.correlate_metrics_and_logs(self, insight_context)
      analytics.identify_performance_bottlenecks(self)
      analytics.generate_optimization_recommendations(self)
      analytics.create_observability_reports(self)
    end
  end

  # 🚀 PRIVATE METHODS
  private

  def with_correlation_id(&block)
    CorrelationManager.with_correlation_id(&block)
  end

  def execute_with_span_context(span, &block)
    @span_manager.with_span_context(span, &block)
  end

  def execute_with_error_handling(&block)
    begin
      yield
    rescue => e
      structured_logger.error('Operation failed', error_context(e))
      raise e
    end
  end

  def operation_context
    {
      compare_list_id: id,
      user_id: user_id,
      product_count: compare_items.count,
      status: status,
      timestamp: Time.current
    }
  end

  def error_context(error)
    operation_context.merge(
      error_class: error.class.name,
      error_message: error.message,
      error_backtrace: error.backtrace&.first
    )
  end

  def metrics_collector
    @metrics_collector ||= MetricsCollector.new
  end

  def structured_logger
    @structured_logger ||= StructuredLogger.new
  end

  def health_monitor
    @health_monitor ||= HealthMonitor.new
  end

  def observability_analytics
    @observability_analytics ||= ObservabilityAnalytics.new
  end
end