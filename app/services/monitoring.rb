# frozen_string_literal: true

# Enterprise-grade Monitoring and Observability Framework
# Provides comprehensive telemetry, metrics, and health monitoring
module Monitoring
  # Observable mixin for adding monitoring capabilities to classes
  module Observable
    extend ActiveSupport::Concern

    included do
      class_attribute :monitoring_enabled, default: true
    end

    def observe(event_name, data = {})
      return unless monitoring_enabled?

      telemetry_data = build_telemetry_data(event_name, data)
      TelemetryCollector.collect(telemetry_data)
    rescue StandardError => e
      # Don't let monitoring failures break business logic
      Rails.logger.warn("Monitoring error: #{e.message}")
    end

    private

    def monitoring_enabled?
      Monitoring.enabled? && monitoring_enabled
    end

    def build_telemetry_data(event_name, data)
      {
        event: event_name,
        source: self.class.name,
        timestamp: Time.current,
        context: extract_context,
        data: data
      }
    end

    def extract_context
      {
        class: self.class.name,
        id: try(:id),
        integration_id: try(:integration_id),
        thread_id: Thread.current.object_id,
        hostname: Socket.gethostname
      }
    end
  end

  # Telemetry Collector for gathering metrics and events
  class TelemetryCollector
    class << self
      def collect(telemetry_data)
        # Collect metrics
        MetricsCollector.collect(telemetry_data)

        # Collect traces
        TracingCollector.collect(telemetry_data)

        # Collect logs
        LoggingCollector.collect(telemetry_data)

        # Store telemetry data
        store_telemetry_data(telemetry_data)
      end

      def collect_metric(name, value, tags = {})
        metric_data = {
          name: name,
          value: value,
          tags: tags,
          timestamp: Time.current
        }

        MetricsCollector.store_metric(metric_data)
      end

      def collect_trace(operation_name, duration, tags = {})
        trace_data = {
          operation: operation_name,
          duration: duration,
          tags: tags,
          timestamp: Time.current
        }

        TracingCollector.store_trace(trace_data)
      end

      private

      def store_telemetry_data(telemetry_data)
        # Store in telemetry store for analysis
        TelemetryStore.append(telemetry_data)
      rescue StandardError => e
        Rails.logger.error("Failed to store telemetry data: #{e.message}")
      end
    end
  end

  # Metrics Collector for performance and business metrics
  class MetricsCollector
    class << self
      def collect(telemetry_data)
        # Extract metrics from telemetry data
        extract_and_store_metrics(telemetry_data)
      end

      def store_metric(metric_data)
        # Store individual metric
        Metric.create!(metric_data)

        # Send to external monitoring systems
        send_to_external_monitors(metric_data)
      rescue StandardError => e
        Rails.logger.error("Failed to store metric: #{e.message}")
      end

      private

      def extract_and_store_metrics(telemetry_data)
        case telemetry_data[:event]
        when /integration\.connect/
          store_connection_metrics(telemetry_data)
        when /integration\.sync/
          store_sync_metrics(telemetry_data)
        when /integration\.connection_test/
          store_connection_test_metrics(telemetry_data)
        when /integration\.health/
          store_health_metrics(telemetry_data)
        end
      end

      def store_connection_metrics(telemetry_data)
        data = telemetry_data[:data]

        collect_metric(
          'integration.connection.duration',
          data[:duration],
          integration_id: data[:integration_id],
          type: 'histogram'
        )

        collect_metric(
          'integration.connection.total',
          1,
          integration_id: data[:integration_id],
          status: 'success',
          type: 'counter'
        )
      end

      def store_sync_metrics(telemetry_data)
        data = telemetry_data[:data]
        context = telemetry_data[:context]

        collect_metric(
          'integration.sync.duration',
          data[:duration],
          integration_id: context[:integration_id],
          type: 'histogram'
        )

        if data[:context] && data[:context][:records_processed]
          collect_metric(
            'integration.sync.records_processed',
            data[:context][:records_processed],
            integration_id: context[:integration_id],
            type: 'counter'
          )
        end
      end

      def store_connection_test_metrics(telemetry_data)
        data = telemetry_data[:data]

        collect_metric(
          'integration.connection_test.latency',
          data[:latency],
          integration_id: data[:integration_id],
          type: 'histogram'
        )
      end

      def store_health_metrics(telemetry_data)
        data = telemetry_data[:data]

        collect_metric(
          'integration.health.score',
          data[:health_score],
          integration_id: data[:integration_id],
          status: data[:health_status],
          type: 'gauge'
        )
      end

      def send_to_external_monitors(metric_data)
        # Send to configured external monitoring systems
        ExternalMonitors.publish_metric(metric_data)
      end
    end
  end

  # Distributed Tracing Collector
  class TracingCollector
    class << self
      def collect(telemetry_data)
        # Create trace span
        create_trace_span(telemetry_data)
      end

      def store_trace(trace_data)
        # Store trace data
        Trace.create!(trace_data)

        # Send to tracing systems
        send_to_tracing_systems(trace_data)
      end

      private

      def create_trace_span(telemetry_data)
        span_data = {
          trace_id: telemetry_data[:context][:trace_id] || generate_trace_id,
          span_id: generate_span_id,
          operation_name: telemetry_data[:event],
          start_time: telemetry_data[:timestamp],
          duration: extract_duration(telemetry_data),
          tags: telemetry_data[:context],
          logs: extract_logs(telemetry_data)
        }

        store_trace(span_data)
      end

      def generate_trace_id
        SecureRandom.hex(16)
      end

      def generate_span_id
        SecureRandom.hex(8)
      end

      def extract_duration(telemetry_data)
        telemetry_data[:data][:duration] || 0
      end

      def extract_logs(telemetry_data)
        # Extract log entries from telemetry data
        telemetry_data[:data][:logs] || []
      end

      def send_to_tracing_systems(trace_data)
        # Send to configured tracing systems (Jaeger, DataDog, etc.)
        ExternalMonitors.publish_trace(trace_data)
      end
    end
  end

  # Logging Collector for structured logging
  class LoggingCollector
    class << self
      def collect(telemetry_data)
        # Create structured log entry
        create_log_entry(telemetry_data)
      end

      def create_log_entry(telemetry_data)
        log_data = {
          level: determine_log_level(telemetry_data),
          message: telemetry_data[:event],
          context: telemetry_data[:context],
          data: telemetry_data[:data],
          timestamp: telemetry_data[:timestamp]
        }

        # Send to logging system
        Rails.logger.info(log_data.to_json)

        # Store in log store if needed
        store_log_entry(log_data)
      end

      private

      def determine_log_level(telemetry_data)
        case telemetry_data[:event]
        when /failed/, /error/, /critical/
          :error
        when /warning/, /degraded/
          :warn
        when /completed/, /success/
          :info
        else
          :debug
        end
      end

      def store_log_entry(log_data)
        # Store in log storage for analysis
        ApplicationLog.create!(log_data)
      rescue StandardError => e
        # Don't let logging failures break the system
        Rails.logger.warn("Failed to store log entry: #{e.message}")
      end
    end
  end

  # Telemetry Store for storing telemetry data
  class TelemetryStore
    class << self
      def append(telemetry_data)
        # Store telemetry data for analysis
        TelemetryData.create!(
          event: telemetry_data[:event],
          source: telemetry_data[:source],
          context: telemetry_data[:context],
          data: telemetry_data[:data],
          timestamp: telemetry_data[:timestamp]
        )
      rescue StandardError => e
        Rails.logger.error("Failed to store telemetry data: #{e.message}")
      end

      def query(filters = {})
        # Query telemetry data for analysis
        query = TelemetryData.all

        query = query.where(event: filters[:event]) if filters[:event]
        query = query.where(source: filters[:source]) if filters[:source]
        query = query.where('timestamp >= ?', filters[:from]) if filters[:from]
        query = query.where('timestamp <= ?', filters[:to]) if filters[:to]

        query.order(timestamp: :desc)
      end
    end
  end

  # External Monitors integration
  class ExternalMonitors
    class << self
      def publish_metric(metric_data)
        # Publish to external monitoring systems
        case external_monitoring_system
        when :datadog
          publish_to_datadog(metric_data)
        when :prometheus
          publish_to_prometheus(metric_data)
        when :new_relic
          publish_to_new_relic(metric_data)
        when :cloudwatch
          publish_to_cloudwatch(metric_data)
        end
      end

      def publish_trace(trace_data)
        # Publish to distributed tracing systems
        case distributed_tracing_system
        when :jaeger
          publish_to_jaeger(trace_data)
        when :datadog
          publish_to_datadog_trace(trace_data)
        when :aws_xray
          publish_to_xray(trace_data)
        end
      end

      private

      def external_monitoring_system
        ENV.fetch('EXTERNAL_MONITORING_SYSTEM', :none).to_sym
      end

      def distributed_tracing_system
        ENV.fetch('DISTRIBUTED_TRACING_SYSTEM', :none).to_sym
      end

      def publish_to_datadog(metric_data)
        # Implementation for DataDog StatsD
        # Would use dogstatsd-ruby gem
      end

      def publish_to_prometheus(metric_data)
        # Implementation for Prometheus
        # Would use prometheus-client gem
      end

      def publish_to_new_relic(metric_data)
        # Implementation for New Relic
        # Would use newrelic_rpm gem
      end

      def publish_to_cloudwatch(metric_data)
        # Implementation for AWS CloudWatch
        # Would use aws-sdk-cloudwatch gem
      end

      def publish_to_jaeger(trace_data)
        # Implementation for Jaeger
        # Would use jaeger-client gem
      end

      def publish_to_datadog_trace(trace_data)
        # Implementation for DataDog tracing
        # Would use ddtrace gem
      end

      def publish_to_xray(trace_data)
        # Implementation for AWS X-Ray
        # Would use aws-sdk-xray gem
      end
    end
  end

  # Performance Tracker for tracking performance metrics
  class PerformanceTracker
    class << self
      def record(integration_id:, metric:, value:, timestamp: Time.current, tags: {})
        PerformanceMetric.create!(
          integration_id: integration_id,
          metric: metric,
          value: value,
          timestamp: timestamp,
          tags: tags
        )
      rescue StandardError => e
        Rails.logger.error("Failed to record performance metric: #{e.message}")
      end

      def get_metrics(integration_id, metric, time_range = 24.hours)
        PerformanceMetric.where(
          integration_id: integration_id,
          metric: metric,
          timestamp: time_range.ago..Time.current
        ).order(timestamp: :desc)
      end

      def calculate_percentile(integration_id, metric, percentile, time_range = 24.hours)
        metrics = get_metrics(integration_id, metric, time_range)
        values = metrics.pluck(:value).sort

        index = (percentile / 100.0 * (values.length - 1)).round
        values[index] || 0
      end

      def calculate_average(integration_id, metric, time_range = 24.hours)
        metrics = get_metrics(integration_id, metric, time_range)
        return 0.0 if metrics.empty?

        metrics.average(:value)
      end
    end
  end

  # Anomaly Detector for detecting performance and behavior anomalies
  class AnomalyDetector
    class << self
      def detect(anomaly_type, data = {})
        case anomaly_type
        when :slow_sync
          detect_slow_sync(data)
        when :high_error_rate
          detect_high_error_rate(data)
        when :unusual_pattern
          detect_unusual_pattern(data)
        when :performance_degradation
          detect_performance_degradation(data)
        end
      rescue StandardError => e
        Rails.logger.error("Anomaly detection error: #{e.message}")
      end

      private

      def detect_slow_sync(data)
        integration_id = data[:integration_id]
        duration = data[:duration]

        # Compare against historical P95
        p95_duration = PerformanceTracker.calculate_percentile(
          integration_id,
          :sync_duration,
          95,
          7.days
        )

        # If current duration is > 2x P95, it's anomalous
        if duration > (p95_duration * 2)
          create_anomaly_record(
            :slow_sync,
            integration_id,
            "Sync duration #{duration}s exceeds 2x P95 (#{p95_duration}s)",
            data
          )
        end
      end

      def detect_high_error_rate(data)
        integration_id = data[:integration_id]
        current_rate = data[:error_rate]

        # Compare against historical average
        avg_rate = PerformanceTracker.calculate_average(
          integration_id,
          :error_rate,
          7.days
        )

        # If current rate is > 3x average, it's anomalous
        if current_rate > (avg_rate * 3)
          create_anomaly_record(
            :high_error_rate,
            integration_id,
            "Error rate #{current_rate}% exceeds 3x historical average (#{avg_rate}%)",
            data
          )
        end
      end

      def detect_unusual_pattern(data)
        # Detect unusual access patterns or data volumes
        create_anomaly_record(
          :unusual_pattern,
          data[:integration_id],
          "Unusual pattern detected in #{data[:pattern_type]}",
          data
        )
      end

      def detect_performance_degradation(data)
        # Detect gradual performance degradation
        create_anomaly_record(
          :performance_degradation,
          data[:integration_id],
          "Performance degradation detected in #{data[:metric]}",
          data
        )
      end

      def create_anomaly_record(anomaly_type, integration_id, message, data)
        AnomalyRecord.create!(
          anomaly_type: anomaly_type,
          integration_id: integration_id,
          message: message,
          data: data,
          detected_at: Time.current,
          status: :detected
        )

        # Send alert
        AlertService.alert(:anomaly_detected, {
          anomaly_type: anomaly_type,
          integration_id: integration_id,
          message: message
        })
      rescue StandardError => e
        Rails.logger.error("Failed to create anomaly record: #{e.message}")
      end
    end
  end

  # Alert Service for sending notifications and alerts
  class AlertService
    class << self
      def alert(alert_type, data = {})
        # Send alert via configured channels
        send_via_channels(alert_type, data)

        # Create alert record
        create_alert_record(alert_type, data)

        # Trigger escalation if needed
        trigger_escalation(alert_type, data)
      end

      private

      def send_via_channels(alert_type, data)
        # Send via configured notification channels
        notification_channels.each do |channel|
          send_via_channel(channel, alert_type, data)
        end
      end

      def send_via_channel(channel, alert_type, data)
        case channel
        when :slack
          SlackNotifier.send_alert(alert_type, data)
        when :email
          EmailNotifier.send_alert(alert_type, data)
        when :webhook
          WebhookNotifier.send_alert(alert_type, data)
        when :sms
          SmsNotifier.send_alert(alert_type, data)
        end
      rescue StandardError => e
        Rails.logger.error("Failed to send alert via #{channel}: #{e.message}")
      end

      def notification_channels
        ENV.fetch('ALERT_CHANNELS', 'email').split(',').map(&:strip).map(&:to_sym)
      end

      def create_alert_record(alert_type, data)
        AlertRecord.create!(
          alert_type: alert_type,
          data: data,
          sent_at: Time.current,
          status: :sent
        )
      rescue StandardError => e
        Rails.logger.error("Failed to create alert record: #{e.message}")
      end

      def trigger_escalation(alert_type, data)
        # Trigger escalation for critical alerts
        return unless critical_alert_types.include?(alert_type)

        EscalationService.escalate(alert_type, data)
      end

      def critical_alert_types
        [:integration_critical, :security_breach, :data_loss, :system_down]
      end
    end
  end

  # Configuration check
  def self.enabled?
    ENV.fetch('MONITORING_ENABLED', 'true') == 'true'
  end

  # Database models for storing monitoring data
  class Metric < ApplicationRecord
    belongs_to :integration, optional: true

    validates :name, :value, presence: true

    serialize :tags, JSON

    scope :recent, -> { where('timestamp >= ?', 1.hour.ago) }
    scope :for_integration, ->(integration_id) { where(integration_id: integration_id) }
  end

  class Trace < ApplicationRecord
    belongs_to :integration, optional: true

    validates :operation, :duration, presence: true

    serialize :tags, JSON
    serialize :logs, JSON
  end

  class ApplicationLog < ApplicationRecord
    validates :level, :message, presence: true

    serialize :context, JSON
    serialize :data, JSON

    scope :recent, -> { where('timestamp >= ?', 1.hour.ago) }
    scope :by_level, ->(level) { where(level: level) }
  end

  class TelemetryData < ApplicationRecord
    validates :event, :source, presence: true

    serialize :context, JSON
    serialize :data, JSON

    scope :recent, -> { where('timestamp >= ?', 1.hour.ago) }
    scope :by_event, ->(event) { where(event: event) }
  end

  class PerformanceMetric < ApplicationRecord
    belongs_to :integration

    validates :metric, :value, presence: true

    serialize :tags, JSON

    scope :recent, -> { where('timestamp >= ?', 24.hours.ago) }
  end

  class AnomalyRecord < ApplicationRecord
    belongs_to :integration

    validates :anomaly_type, :message, presence: true

    serialize :data, JSON

    scope :active, -> { where(status: :detected) }
    scope :recent, -> { where('detected_at >= ?', 24.hours.ago) }
  end

  class AlertRecord < ApplicationRecord
    validates :alert_type, presence: true

    serialize :data, JSON

    scope :recent, -> { where('sent_at >= ?', 24.hours.ago) }
  end
end