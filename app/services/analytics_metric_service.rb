# frozen_string_literal: true

# Service class for handling AnalyticsMetric business logic
# Extracted from the monolithic model to adhere to Single Responsibility Principle
# Implements Clean Architecture Application Layer for use cases
class AnalyticsMetricService
  include AnalyticsMetricConfiguration

  # Dependency injection for external services
  attr_accessor :repository, :cache, :event_publisher, :anomaly_detector, :predictive_model

  def initialize(repository: AnalyticsMetricRepository.new,
                 cache: Rails.cache,
                 event_publisher: EventPublisher.new,
                 anomaly_detector: AnomalyDetectionService.new,
                 predictive_model: MachineLearningService.new)
    @repository = repository
    @cache = cache
    @event_publisher = event_publisher
    @anomaly_detector = anomaly_detector
    @predictive_model = predictive_model
  end

  # Enhanced metric recording with comprehensive metadata
  def record_realtime_metric(name:, value:, metric_type:, dimensions: {}, metadata: {},
                             source_system: nil, quality_score: nil)
    validate_metric_data(name, value, metric_type, dimensions, metadata)

    transaction do
      metric = build_metric(name, value, metric_type, dimensions, metadata, source_system, quality_score)
      metric.save!

      # Trigger immediate processing
      process_real_time_analytics(metric)

      # Publish event for downstream consumers
      event_publisher.publish('analytics_metric.recorded', metric.to_event_data)

      metric
    end
  rescue ActiveRecord::RecordInvalid => e
    handle_validation_error(e)
  rescue StandardError => e
    handle_processing_error(e, name, value)
  end

  # Batch metric recording for high-volume scenarios
  def record_batch_metrics(metrics_data:, batch_metadata: {})
    validate_batch_data(metrics_data, batch_metadata)

    transaction do
      batch_id = generate_batch_id
      processed_metrics = []

      metrics_data.each do |metric_data|
        metric = build_metric_from_batch(metric_data, batch_id, batch_metadata)
        metric.save!
        processed_metrics << metric
      end

      # Process batch analytics
      process_batch_analytics(processed_metrics, batch_metadata)

      # Publish batch completion event
      event_publisher.publish('analytics_metric.batch_completed', {
        batch_id: batch_id,
        count: processed_metrics.size,
        metadata: batch_metadata
      })

      processed_metrics
    end
  rescue StandardError => e
    handle_batch_error(e, metrics_data, batch_metadata)
  end

  # Advanced metric retrieval with intelligent caching
  def get_metric_with_insights(metric_name:, date_range:, dimensions: {}, **options)
    cache_key = build_cache_key(metric_name, date_range, dimensions, options)

    cache.fetch(cache_key, expires_in: cache_expiration(:short)) do
      # Retrieve base metrics
      metrics = repository.retrieve_metrics_with_dimensions(metric_name, date_range, dimensions)

      # Enrich with derived insights
      enriched_metrics = enrich_metrics_with_insights(metrics, options)

      # Add predictive analytics if requested
      if options[:include_predictions]
        enriched_metrics = add_predictive_insights(enriched_metrics, options)
      end

      enriched_metrics
    end
  rescue StandardError => e
    handle_retrieval_error(e, metric_name, date_range)
  end

  # Generate comprehensive analytics report
  def generate_analytics_report(report_type:, date_range:, dimensions: {},
                                include_predictions: false, format: :json)
    validate_report_parameters(report_type, date_range, format)

    report_generator = AnalyticsReportGenerator.new(
      report_type: report_type,
      date_range: date_range,
      dimensions: dimensions,
      include_predictions: include_predictions,
      service: self
    )

    report_data = report_generator.generate

    format_report(report_data, format)
  rescue StandardError => e
    handle_report_error(e, report_type, format)
  end

  # Process real-time analytics pipeline
  def process_real_time_analytics(metric)
    # Update real-time aggregations
    update_real_time_aggregations(metric)

    # Check for anomalies
    detect_anomalies(metric) if should_check_anomalies?(metric)

    # Trigger alerts if thresholds exceeded
    trigger_alerts_if_needed(metric)

    # Update predictive models
    update_predictive_models(metric) if predictive_analytics_enabled?(metric)
  rescue StandardError => e
    handle_real_time_error(e, metric)
  end

  # Calculate comprehensive trend analysis
  def calculate_trend_analysis(metric, days: 30, include_confidence: true)
    historical_data = repository.get_historical_data(metric, days)

    trend_analysis = StatisticalAnalysisService.analyze_trend(
      data: historical_data,
      include_confidence: include_confidence
    )

    enrich_trend_with_context(trend_analysis, metric)
  rescue StandardError => e
    handle_trend_error(e, metric, days)
  end

  # Generate predictive forecast
  def generate_predictive_forecast(metric, horizon: 30.days, confidence_interval: 0.95)
    return unless predictive_analytics_enabled?(metric)

    training_data = prepare_training_data(metric, horizon * 2)

    forecast = predictive_model.train_and_forecast(
      metric_name: metric.metric_name,
      training_data: training_data,
      horizon: horizon,
      confidence_interval: confidence_interval
    )

    enrich_forecast_with_context(forecast, metric)
  rescue StandardError => e
    handle_forecast_error(e, metric, horizon)
  end

  # Perform anomaly detection
  def detect_anomalies(metric, sensitivity: :medium)
    anomalies = anomaly_detector.detect_anomalies(
      metric: metric,
      sensitivity: sensitivity,
      historical_window: anomaly_detection_window
    )

    # Record detected anomalies
    record_anomalies(metric, anomalies)

    anomalies.any?
  rescue StandardError => e
    handle_anomaly_error(e, metric)
  end

  # Calculate data quality score
  def calculate_data_quality_score(metric)
    quality_factors = calculate_quality_factors(metric)

    quality_score = compute_weighted_quality_score(quality_factors)

    update_metric_quality(metric, quality_score)

    quality_score
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  private

  def validate_metric_data(name, value, metric_type, dimensions, metadata)
    raise ArgumentError, 'Metric name is required' if name.blank?
    raise ArgumentError, 'Value must be numeric' unless value.is_a?(Numeric)
    raise ArgumentError, "Invalid metric type: #{metric_type}" unless metric_type_config(metric_type)
    validate_dimensions(dimensions, metric_type)
    validate_metadata(metadata)
  end

  def validate_batch_data(metrics_data, batch_metadata)
    raise ArgumentError, 'Metrics data cannot be empty' if metrics_data.empty?
    raise ArgumentError, 'Batch size exceeds threshold' if metrics_data.size > batch_size_threshold
  end

  def validate_report_parameters(report_type, date_range, format)
    raise ArgumentError, "Invalid report type: #{report_type}" unless valid_report_type?(report_type)
    raise ArgumentError, "Invalid format: #{format}" unless report_format_supported?(format)
    raise ArgumentError, 'Date range is required' if date_range.blank?
  end

  def build_metric(name, value, metric_type, dimensions, metadata, source_system, quality_score)
    AnalyticsMetric.new(
      metric_name: name,
      value: value,
      metric_type: metric_type,
      dimensions: dimensions,
      metadata: metadata,
      source_system: source_system,
      data_quality_score: quality_score || calculate_data_quality(dimensions, metadata),
      aggregation_type: metric_type_config(metric_type)[:aggregation_type],
      real_time_processing: true,
      dimensions_hash: generate_dimensions_hash(dimensions)
    ).tap { |m| m.date = Time.current }
  end

  def build_metric_from_batch(metric_data, batch_id, batch_metadata)
    build_metric(
      metric_data[:name],
      metric_data[:value],
      metric_data[:metric_type],
      metric_data[:dimensions] || {},
      metric_data[:metadata] || {},
      metric_data[:source_system],
      metric_data[:quality_score]
    ).tap do |metric|
      metric.batch_id = batch_id
      metric.batch_metadata = batch_metadata
      metric.processed_at = Time.current
    end
  end

  def process_batch_analytics(metrics, batch_metadata)
    # Asynchronous processing for large batches
    if metrics.size > 100
      BatchAnalyticsJob.perform_later(metrics.map(&:id), batch_metadata)
    else
      metrics.each { |metric| process_real_time_analytics(metric) }
    end
  end

  def update_real_time_aggregations(metric)
    # Update hourly, daily aggregations
    RealTimeAggregationJob.perform_later(metric.id)
  end

  def detect_anomalies(metric)
    detect_anomalies(metric) if should_check_anomalies?(metric)
  end

  def trigger_alerts_if_needed(metric)
    metric.metric_alerts.active.each do |alert|
      if alert.threshold_exceeded?(metric.value)
        alert.trigger!(current_value: metric.value, metric: metric)
      end
    end
  end

  def update_predictive_models(metric)
    PredictiveModelUpdateJob.perform_later(metric.id)
  end

  def enrich_metrics_with_insights(metrics, options)
    metrics.map do |metric|
      {
        metric: metric,
        statistical_insights: calculate_statistical_insights(metric),
        trend_analysis: calculate_trend_analysis(metric, days: options[:trend_window] || 30),
        quality_assessment: assess_data_quality(metric),
        anomaly_status: current_anomaly_status(metric)
      }
    end
  end

  def add_predictive_insights(metrics, options)
    metrics.each do |metric_data|
      metric_data[:predictive_forecast] = generate_predictive_forecast(
        metric_data[:metric],
        horizon: options[:forecast_horizon] || 30.days,
        confidence_interval: options[:confidence_interval] || 0.95
      )
    end
    metrics
  end

  def format_report(report_data, format)
    case format.to_sym
    when :json then report_data.to_json
    when :csv then export_to_csv(report_data)
    when :excel then export_to_excel(report_data)
    when :pdf then export_to_pdf(report_data)
    else report_data
    end
  end

  def calculate_quality_factors(metric)
    {
      completeness: calculate_completeness_score(metric),
      accuracy: calculate_accuracy_score(metric),
      timeliness: calculate_timeliness_score(metric),
      consistency: calculate_consistency_score(metric),
      validity: calculate_validity_score(metric)
    }
  end

  def compute_weighted_quality_score(factors)
    weights = [0.25, 0.25, 0.2, 0.15, 0.15]
    factors.values.zip(weights).sum { |factor, weight| factor * weight }
  end

  def update_metric_quality(metric, score)
    metric.data_quality_level = determine_quality_level(score)
    metric.data_quality_score = score
    metric.save! if metric.changed?
  end

  def record_anomalies(metric, anomalies)
    anomalies.each do |anomaly|
      metric.anomaly_detections.create!(
        anomaly_type: anomaly[:type],
        severity: anomaly[:severity],
        confidence_score: anomaly[:confidence],
        detected_value: anomaly[:detected_value],
        expected_range: anomaly[:expected_range],
        detection_method: anomaly[:method]
      )
    end
  end

  def generate_batch_id
    "batch_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
  end

  def build_cache_key(metric_name, date_range, dimensions, options)
    dimensions_hash = generate_dimensions_hash(dimensions)
    options_hash = options.hash
    "analytics_metric:#{metric_name}:#{date_range.begin}:#{date_range.end}:#{dimensions_hash}:#{options_hash}"
  end

  def cache_expiration(type)
    CACHE_EXPIRATION[type.to_sym] || 15.minutes
  end

  def generate_dimensions_hash(dimensions)
    return nil if dimensions.blank?
    Digest::SHA256.hexdigest(dimensions.to_json)
  end

  def calculate_data_quality(dimensions, metadata)
    # Simplified quality calculation
    0.9  # Placeholder
  end

  def validate_dimensions(dimensions, metric_type)
    required = metric_type_config(metric_type)[:required_dimensions] || []
    provided = dimensions.keys
    missing = required - provided
    raise ArgumentError, "Missing required dimensions: #{missing.join(', ')}" unless missing.empty?
  end

  def validate_metadata(metadata)
    # Add metadata validation logic
  end

  def valid_report_type?(type)
    # Define valid report types
    %w[summary detailed predictive].include?(type)
  end

  def predictive_analytics_enabled?(metric)
    metric_type_config(metric.metric_type)[:predictive_analytics]
  end

  def should_check_anomalies?(metric)
    metric_type_config(metric.metric_type)[:anomaly_detection]
  end

  def calculate_completeness_score(metric)
    required_fields = metric_type_config(metric.metric_type)[:required_dimensions] || []
    provided_fields = metric.dimensions&.keys || []
    return 1.0 if required_fields.empty?
    (provided_fields & required_fields).count.to_f / required_fields.count
  end

  def calculate_accuracy_score(metric)
    # Placeholder for accuracy calculation
    0.95
  end

  def calculate_timeliness_score(metric)
    return 1.0 unless metric.real_time_processing?
    hours_old = ((Time.current - metric.processed_at) / 1.hour).to_f
    [1.0 - (hours_old * 0.1), 0.0].max
  end

  def calculate_consistency_score(metric)
    # Placeholder for consistency calculation
    0.90
  end

  def calculate_validity_score(metric)
    # Placeholder for validity calculation
    0.92
  end

  def determine_quality_level(score)
    case score
    when 0.95..1.0 then :excellent
    when 0.85...0.95 then :good
    when 0.70...0.85 then :fair
    else :poor
    end
  end

  def calculate_statistical_insights(metric)
    # Placeholder
    {}
  end

  def assess_data_quality(metric)
    # Placeholder
    {}
  end

  def current_anomaly_status(metric)
    # Placeholder
    {}
  end

  def enrich_trend_with_context(trend, metric)
    # Placeholder
    trend
  end

  def enrich_forecast_with_context(forecast, metric)
    # Placeholder
    forecast
  end

  def prepare_training_data(metric, size)
    # Placeholder
    []
  end

  def export_to_csv(data)
    # Placeholder
    data.to_csv
  end

  def export_to_excel(data)
    # Placeholder
    data.to_excel
  end

  def export_to_pdf(data)
    # Placeholder
    data.to_pdf
  end

  def transaction(&block)
    ActiveRecord::Base.transaction(&block)
  end

  def handle_validation_error(error)
    Rails.logger.error("Metric validation failed: #{error.message}")
    raise
  end

  def handle_processing_error(error, name, value)
    Rails.logger.error("Metric processing failed for #{name}: #{error.message}")
    # Implement retry logic or dead letter queue
    raise
  end

  def handle_batch_error(error, metrics_data, batch_metadata)
    Rails.logger.error("Batch processing failed: #{error.message}")
    # Implement batch retry or partial success handling
    raise
  end

  def handle_retrieval_error(error, metric_name, date_range)
    Rails.logger.error("Metric retrieval failed for #{metric_name}: #{error.message}")
    # Implement fallback or caching refresh
    raise
  end

  def handle_report_error(error, report_type, format)
    Rails.logger.error("Report generation failed for #{report_type}: #{error.message}")
    # Implement report retry or alternative format
    raise
  end

  def handle_real_time_error(error, metric)
    Rails.logger.error("Real-time processing failed for metric #{metric.id}: #{error.message}")
    # Implement circuit breaker or degradation
    raise
  end

  def handle_trend_error(error, metric, days)
    Rails.logger.error("Trend analysis failed for metric #{metric.id}: #{error.message}")
    # Implement fallback trend calculation
    raise
  end

  def handle_forecast_error(error, metric, horizon)
    Rails.logger.error("Forecast generation failed for metric #{metric.id}: #{error.message}")
    # Implement fallback forecast
    raise
  end

  def handle_anomaly_error(error, metric)
    Rails.logger.error("Anomaly detection failed for metric #{metric.id}: #{error.message}")
    # Implement fallback anomaly detection
    raise
  end

  def handle_quality_error(error, metric)
    Rails.logger.error("Quality calculation failed for metric #{metric.id}: #{error.message}")
    # Implement fallback quality score
    raise
  end
end