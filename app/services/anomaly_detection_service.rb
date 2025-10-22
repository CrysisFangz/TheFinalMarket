# frozen_string_literal: true

# Service class for handling AnalyticsMetric anomaly detection
# Extracted from the monolithic model to improve modularity and accuracy
# Implements Clean Architecture Application Layer for anomaly use cases
class AnomalyDetectionService
  include AnalyticsMetricConfiguration

  # Dependency injection for external services
  attr_accessor :statistical_service, :machine_learning_service, :cache, :alert_service

  def initialize(statistical_service: StatisticalAnalysisService.new,
                 machine_learning_service: MachineLearningService.new,
                 cache: Rails.cache,
                 alert_service: AlertService.new)
    @statistical_service = statistical_service
    @machine_learning_service = machine_learning_service
    @cache = cache
    @alert_service = alert_service
  end

  # Detect anomalies for a metric
  def detect_anomalies(metric, sensitivity: :medium, historical_window: anomaly_detection_window)
    cache_key = "anomalies:#{metric.id}:#{sensitivity}:#{historical_window}"

    cache.fetch(cache_key, expires_in: cache_expiration(:short)) do
      historical_data = get_historical_data(metric, historical_window)

      anomalies = case sensitivity.to_sym
                  when :low
                    detect_with_low_sensitivity(historical_data, metric)
                  when :medium
                    detect_with_medium_sensitivity(historical_data, metric)
                  when :high
                    detect_with_high_sensitivity(historical_data, metric)
                  else
                    raise ArgumentError, "Unknown sensitivity level: #{sensitivity}"
                  end

      # Record detected anomalies
      record_anomalies(metric, anomalies)

      # Trigger alerts if necessary
      trigger_alerts(metric, anomalies)

      anomalies
    end
  rescue StandardError => e
    handle_anomaly_error(e, metric)
  end

  # Detect anomalies using statistical methods
  def detect_statistical_anomalies(metric, method: :zscore, threshold: 2.5)
    historical_data = get_historical_data(metric, anomaly_detection_window)

    case method.to_sym
    when :zscore
      detect_zscore_anomalies(historical_data, metric, threshold)
    when :iqr
      detect_iqr_anomalies(historical_data, metric)
    when :isolation_forest
      detect_isolation_forest_anomalies(historical_data, metric)
    when :local_outlier_factor
      detect_lof_anomalies(historical_data, metric)
    else
      raise ArgumentError, "Unknown detection method: #{method}"
    end
  rescue StandardError => e
    handle_anomaly_error(e, metric)
  end

  # Detect anomalies using machine learning
  def detect_ml_anomalies(metric, model_type: :autoencoder)
    historical_data = get_historical_data(metric, anomaly_detection_window)

    ml_anomalies = machine_learning_service.detect_anomalies(
      data: historical_data,
      model_type: model_type,
      metric_name: metric.metric_name
    )

    format_ml_anomalies(ml_anomalies, metric)
  rescue StandardError => e
    handle_anomaly_error(e, metric)
  end

  # Detect seasonal anomalies
  def detect_seasonal_anomalies(metric)
    seasonal_data = get_seasonal_data(metric)

    anomalies = statistical_service.detect_seasonal_anomalies(seasonal_data, metric.value)

    format_seasonal_anomalies(anomalies, metric)
  rescue StandardError => e
    handle_anomaly_error(e, metric)
  end

  # Detect trend anomalies
  def detect_trend_anomalies(metric)
    trend_data = get_trend_data(metric)

    anomalies = statistical_service.detect_trend_anomalies(trend_data, metric.value)

    format_trend_anomalies(anomalies, metric)
  rescue StandardError => e
    handle_anomaly_error(e, metric)
  end

  # Detect contextual anomalies
  def detect_contextual_anomalies(metric)
    contextual_data = get_contextual_data(metric)

    anomalies = statistical_service.detect_contextual_anomalies(contextual_data, metric.value)

    format_contextual_anomalies(anomalies, metric)
  rescue StandardError => e
    handle_anomaly_error(e, metric)
  end

  # Perform comprehensive anomaly detection
  def perform_comprehensive_detection(metric, sensitivity: :medium)
    anomalies = []

    # Statistical anomalies
    anomalies += detect_statistical_anomalies(metric, sensitivity: sensitivity)

    # ML anomalies
    anomalies += detect_ml_anomalies(metric) if feature_enabled?(:predictive_analytics)

    # Seasonal anomalies
    anomalies += detect_seasonal_anomalies(metric)

    # Trend anomalies
    anomalies += detect_trend_anomalies(metric)

    # Contextual anomalies
    anomalies += detect_contextual_anomalies(metric)

    # Deduplicate and prioritize
    deduplicate_anomalies(anomalies)
  rescue StandardError => e
    handle_anomaly_error(e, metric)
  end

  # Calculate anomaly score
  def calculate_anomaly_score(metric)
    anomalies = detect_anomalies(metric)

    # Weighted score based on anomaly types and severities
    score = 0.0
    weights = { low: 0.3, medium: 0.6, high: 1.0 }

    anomalies.each do |anomaly|
      score += weights[anomaly[:severity].to_sym] || 0.5
    end

    score / anomalies.count if anomalies.any?
  rescue StandardError => e
    handle_anomaly_error(e, metric)
  end

  # Generate anomaly report
  def generate_anomaly_report(metric, format: :json)
    anomalies = detect_anomalies(metric)

    report_data = {
      metric_id: metric.id,
      metric_name: metric.metric_name,
      detection_timestamp: Time.current,
      anomalies: anomalies,
      anomaly_score: calculate_anomaly_score(metric),
      detection_method: 'comprehensive',
      report_version: '1.0'
    }

    case format.to_sym
    when :json
      report_data.to_json
    when :html
      generate_html_anomaly_report(report_data)
    when :pdf
      generate_pdf_anomaly_report(report_data)
    else
      report_data
    end
  rescue StandardError => e
    handle_anomaly_error(e, metric)
  end

  # Monitor anomaly trends
  def monitor_anomaly_trends(metric, days: 30)
    cache_key = "anomaly_trends:#{metric.id}:#{days}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      historical_anomalies = get_historical_anomalies(metric, days)

      {
        trend: calculate_anomaly_trend(historical_anomalies),
        frequency: historical_anomalies.count / days.to_f,
        average_severity: average_severity(historical_anomalies),
        peak_periods: identify_peak_periods(historical_anomalies),
        anomaly_types: group_by_type(historical_anomalies)
      }
    end
  rescue StandardError => e
    handle_anomaly_error(e, metric)
  end

  # Alert on anomaly detection
  def alert_on_anomaly(metric, anomaly)
    alert_service.send_anomaly_alert(
      metric: metric,
      anomaly: anomaly,
      priority: anomaly[:severity]
    )
  rescue StandardError => e
    handle_anomaly_error(e, metric)
  end

  private

  def get_historical_data(metric, window)
    AnalyticsMetric.where(metric_name: metric.metric_name)
                   .where('date >= ?', window.ago)
                   .order(date: :asc)
                   .pluck(:value)
  end

  def get_seasonal_data(metric)
    # Get seasonal data for the metric
    AnalyticsMetric.where(metric_name: metric.metric_name)
                   .where('date >= ?', 1.year.ago)
                   .order(date: :asc)
                   .pluck(:value)
  end

  def get_trend_data(metric)
    # Get trend data for the metric
    AnalyticsMetric.where(metric_name: metric.metric_name)
                   .where('date >= ?', 90.days.ago)
                   .order(date: :asc)
                   .pluck(:value)
  end

  def get_contextual_data(metric)
    # Get contextual data including dimensions
    AnalyticsMetric.where(metric_name: metric.metric_name)
                   .where('date >= ?', 30.days.ago)
                   .pluck(:value, :dimensions)
  end

  def detect_with_low_sensitivity(data, metric)
    detect_statistical_anomalies(metric, method: :zscore, threshold: 2.0)
  end

  def detect_with_medium_sensitivity(data, metric)
    detect_statistical_anomalies(metric, method: :zscore, threshold: 2.5)
  end

  def detect_with_high_sensitivity(data, metric)
    detect_statistical_anomalies(metric, method: :zscore, threshold: 3.0)
  end

  def detect_zscore_anomalies(data, metric, threshold)
    mean = statistical_service.calculate_mean(data)
    std_dev = statistical_service.calculate_standard_deviation(data)

    anomalies = []
    data.each_with_index do |value, index|
      z_score = (value - mean).abs / std_dev
      if z_score > threshold
        anomalies << {
          type: :zscore,
          severity: z_score > 3.0 ? :high : :medium,
          confidence: [0.8, z_score / 4.0].min,
          detected_value: value,
          expected_range: [mean - threshold * std_dev, mean + threshold * std_dev],
          detection_method: :zscore,
          index: index
        }
      end
    end

    anomalies
  end

  def detect_iqr_anomalies(data, metric)
    # Implementation for IQR anomaly detection
    []
  end

  def detect_isolation_forest_anomalies(data, metric)
    # Implementation for Isolation Forest
    []
  end

  def detect_lof_anomalies(data, metric)
    # Implementation for Local Outlier Factor
    []
  end

  def format_ml_anomalies(ml_anomalies, metric)
    # Format ML anomalies
    ml_anomalies.map do |anomaly|
      anomaly.merge(type: :ml, detection_method: :machine_learning)
    end
  end

  def format_seasonal_anomalies(anomalies, metric)
    anomalies.map do |anomaly|
      anomaly.merge(type: :seasonal, detection_method: :seasonal_analysis)
    end
  end

  def format_trend_anomalies(anomalies, metric)
    anomalies.map do |anomaly|
      anomaly.merge(type: :trend, detection_method: :trend_analysis)
    end
  end

  def format_contextual_anomalies(anomalies, metric)
    anomalies.map do |anomaly|
      anomaly.merge(type: :contextual, detection_method: :contextual_analysis)
    end
  end

  def record_anomalies(metric, anomalies)
    anomalies.each do |anomaly|
      metric.anomaly_detections.create!(
        anomaly_type: anomaly[:type],
        severity: anomaly[:severity],
        confidence_score: anomaly[:confidence],
        detected_value: anomaly[:detected_value],
        expected_range: anomaly[:expected_range],
        detection_method: anomaly[:detection_method]
      )
    end
  end

  def trigger_alerts(metric, anomalies)
    high_severity_anomalies = anomalies.select { |a| a[:severity] == :high }

    high_severity_anomalies.each do |anomaly|
      alert_on_anomaly(metric, anomaly)
    end
  end

  def deduplicate_anomalies(anomalies)
    # Remove duplicate anomalies based on type and value
    anomalies.uniq { |a| [a[:type], a[:detected_value]] }
  end

  def get_historical_anomalies(metric, days)
    metric.anomaly_detections.where('created_at >= ?', days.ago)
  end

  def calculate_anomaly_trend(anomalies)
    return :stable if anomalies.size < 2

    recent = anomalies[-10..-1] || anomalies
    older = anomalies[0...-10] || []

    recent_avg = recent.sum { |a| severity_score(a[:severity]) } / recent.size
    older_avg = older.sum { |a| severity_score(a[:severity]) } / older.size

    if recent_avg > older_avg * 1.2
      :increasing
    elsif recent_avg < older_avg * 0.8
      :decreasing
    else
      :stable
    end
  end

  def average_severity(anomalies)
    return 0.0 if anomalies.empty?

    total = anomalies.sum { |a| severity_score(a[:severity]) }
    total / anomalies.size
  end

  def severity_score(severity)
    { low: 1, medium: 2, high: 3 }[severity.to_sym] || 1
  end

  def identify_peak_periods(anomalies)
    # Group anomalies by hour/day and find peaks
    {}
  end

  def group_by_type(anomalies)
    anomalies.group_by { |a| a[:type] }.transform_values(&:count)
  end

  def generate_html_anomaly_report(data)
    # Placeholder
    data.to_html
  end

  def generate_pdf_anomaly_report(data)
    # Placeholder
    data.to_pdf
  end

  def cache_expiration(type)
    CACHE_EXPIRATION[type.to_sym] || 15.minutes
  end

  def handle_anomaly_error(error, metric)
    Rails.logger.error("Anomaly detection failed for metric #{metric.id}: #{error.message}")
    # Implement fallback anomaly detection
    []
  end
end