# frozen_string_literal: true

# Service class for handling AnalyticsMetric data quality assessment
# Extracted from the monolithic model to improve modularity and accuracy
# Implements Clean Architecture Application Layer for quality use cases
class AnalyticsQualityService
  include AnalyticsMetricConfiguration

  # Dependency injection for external services
  attr_accessor :validation_service, :cache

  def initialize(validation_service: AnalyticsValidationService.new,
                 cache: Rails.cache)
    @validation_service = validation_service
    @cache = cache
  end

  # Assess overall data quality
  def assess_data_quality(metric)
    cache_key = "data_quality:#{metric.id}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      {
        overall_score: calculate_overall_quality_score(metric),
        level: determine_quality_level(metric),
        factors: calculate_quality_factors(metric),
        recommendations: generate_quality_recommendations(metric),
        last_assessed: Time.current,
        assessment_version: '1.0'
      }
    end
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Calculate data quality score
  def calculate_data_quality_score(metric)
    quality_factors = calculate_quality_factors(metric)

    # Weighted average of quality factors
    weights = [0.25, 0.25, 0.2, 0.15, 0.15]
    quality_score = quality_factors.values.zip(weights).sum { |factor, weight| factor * weight }

    # Update quality level
    update_metric_quality(metric, quality_score)

    quality_score
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Calculate completeness score
  def calculate_completeness_score(metric)
    required_fields = metric_type_config(metric.metric_type)[:required_dimensions] || []
    provided_fields = metric.dimensions&.keys || []

    return 1.0 if required_fields.empty?

    (provided_fields & required_fields).count.to_f / required_fields.count
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Calculate accuracy score based on validation rules
  def calculate_accuracy_score(metric)
    validation_results = validation_service.validate_metric(metric)
    valid_results = validation_results.count { |result| result[:valid] }

    valid_results.to_f / validation_results.count
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Calculate timeliness score
  def calculate_timeliness_score(metric)
    return 1.0 unless metric.real_time_processing?

    # Score based on how recently data was processed
    hours_old = ((Time.current - metric.processed_at) / 1.hour).to_f
    [1.0 - (hours_old * 0.1), 0.0].max
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Calculate consistency score
  def calculate_consistency_score(metric)
    # Check consistency with historical data
    historical_metrics = get_historical_metrics(metric, 30.days)
    consistency_checks = historical_metrics.map do |historical|
      validation_service.check_consistency(metric, historical)
    end

    consistent_count = consistency_checks.count { |check| check[:consistent] }
    consistent_count.to_f / consistency_checks.count
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Calculate validity score
  def calculate_validity_score(metric)
    # Validate against business rules
    validation_rules = validation_service.get_validation_rules(metric.metric_type)
    valid_rules = validation_rules.count do |rule|
      validation_service.validate_rule(metric, rule)
    end

    valid_rules.to_f / validation_rules.count
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Generate quality improvement recommendations
  def generate_quality_recommendations(metric)
    factors = calculate_quality_factors(metric)
    recommendations = []

    if factors[:completeness] < 0.9
      recommendations << {
        type: :completeness,
        priority: :high,
        description: 'Add missing required dimensions',
        action: 'update_dimensions'
      }
    end

    if factors[:accuracy] < 0.9
      recommendations << {
        type: :accuracy,
        priority: :high,
        description: 'Review data sources for accuracy',
        action: 'validate_sources'
      }
    end

    if factors[:timeliness] < 0.9
      recommendations << {
        type: :timeliness,
        priority: :medium,
        description: 'Improve data processing speed',
        action: 'optimize_processing'
      }
    end

    if factors[:consistency] < 0.9
      recommendations << {
        type: :consistency,
        priority: :medium,
        description: 'Standardize data formats',
        action: 'standardize_formats'
      }
    end

    if factors[:validity] < 0.9
      recommendations << {
        type: :validity,
        priority: :high,
        description: 'Fix validation rule violations',
        action: 'fix_validations'
      }
    end

    recommendations
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Validate metric against quality thresholds
  def validate_quality_thresholds(metric)
    quality_score = calculate_data_quality_score(metric)

    case quality_score
    when 0.95..1.0
      :excellent
    when 0.85...0.95
      :good
    when 0.70...0.85
      :fair
    else
      :poor
    end
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Perform comprehensive quality audit
  def perform_quality_audit(metric, audit_type: :comprehensive)
    case audit_type.to_sym
    when :comprehensive
      comprehensive_audit(metric)
    when :quick
      quick_audit(metric)
    when :detailed
      detailed_audit(metric)
    else
      raise ArgumentError, "Unknown audit type: #{audit_type}"
    end
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Calculate data lineage quality
  def calculate_lineage_quality(metric)
    cache_key = "lineage_quality:#{metric.id}"

    cache.fetch(cache_key, expires_in: cache_expiration(:long)) do
      lineage_records = metric.data_lineage_records
      lineage_score = 0.0

      if lineage_records.any?
        # Calculate based on completeness of lineage
        required_lineage_fields = %w[source_system transformation_steps validation_checks]
        provided_fields = lineage_records.first.attributes.keys & required_lineage_fields
        lineage_score = provided_fields.count.to_f / required_lineage_fields.count
      end

      lineage_score
    end
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Calculate provenance quality
  def calculate_provenance_quality(metric)
    cache_key = "provenance_quality:#{metric.id}"

    cache.fetch(cache_key, expires_in: cache_expiration(:long)) do
      provenance_score = 0.0

      if metric.source_system
        provenance_checks = [
          metric.source_system.reliability_score || 0.0,
          metric.source_system.data_freshness || 0.0,
          metric.source_system.accuracy_rating || 0.0
        ]

        provenance_score = provenance_checks.sum / provenance_checks.count
      end

      provenance_score
    end
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Calculate trust score
  def calculate_trust_score(metric)
    quality_score = calculate_data_quality_score(metric)
    lineage_score = calculate_lineage_quality(metric)
    provenance_score = calculate_provenance_quality(metric)

    # Weighted trust score
    weights = [0.5, 0.3, 0.2]
    scores = [quality_score, lineage_score, provenance_score]

    scores.zip(weights).sum { |score, weight| score * weight }
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Generate quality report
  def generate_quality_report(metric, format: :json)
    quality_data = assess_data_quality(metric)

    case format.to_sym
    when :json
      quality_data.to_json
    when :html
      generate_html_report(quality_data)
    when :pdf
      generate_pdf_report(quality_data)
    else
      quality_data
    end
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Monitor quality trends
  def monitor_quality_trends(metric, days: 30)
    cache_key = "quality_trends:#{metric.id}:#{days}"

    cache.fetch(cache_key, expires_in: cache_expiration(:long)) do
      historical_qualities = get_historical_qualities(metric, days)

      {
        trend: calculate_trend(historical_qualities),
        average_score: historical_qualities.sum / historical_qualities.count,
        min_score: historical_qualities.min,
        max_score: historical_qualities.max,
        volatility: calculate_volatility(historical_qualities)
      }
    end
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  # Alert on quality degradation
  def alert_on_quality_degradation(metric, threshold: 0.8)
    current_score = calculate_data_quality_score(metric)

    if current_score < threshold
      QualityAlertJob.perform_later(metric.id, current_score, threshold)
    end
  rescue StandardError => e
    handle_quality_error(e, metric)
  end

  private

  def calculate_quality_factors(metric)
    {
      completeness: calculate_completeness_score(metric),
      accuracy: calculate_accuracy_score(metric),
      timeliness: calculate_timeliness_score(metric),
      consistency: calculate_consistency_score(metric),
      validity: calculate_validity_score(metric)
    }
  end

  def calculate_overall_quality_score(metric)
    factors = calculate_quality_factors(metric)
    weights = [0.25, 0.25, 0.2, 0.15, 0.15]
    factors.values.zip(weights).sum { |factor, weight| factor * weight }
  end

  def determine_quality_level(metric)
    score = calculate_overall_quality_score(metric)

    case score
    when 0.95..1.0 then :excellent
    when 0.85...0.95 then :good
    when 0.70...0.85 then :fair
    else :poor
    end
  end

  def update_metric_quality(metric, score)
    metric.data_quality_level = determine_quality_level(metric)
    metric.data_quality_score = score
    metric.save! if metric.changed?
  end

  def get_historical_metrics(metric, days)
    AnalyticsMetric.where(metric_name: metric.metric_name)
                   .where('date >= ?', days.ago)
                   .order(date: :asc)
  end

  def get_historical_qualities(metric, days)
    historical_metrics = get_historical_metrics(metric, days)
    historical_metrics.map { |m| calculate_overall_quality_score(m) }
  end

  def comprehensive_audit(metric)
    {
      overall_assessment: assess_data_quality(metric),
      lineage_quality: calculate_lineage_quality(metric),
      provenance_quality: calculate_provenance_quality(metric),
      trust_score: calculate_trust_score(metric),
      recommendations: generate_quality_recommendations(metric),
      audit_timestamp: Time.current
    }
  end

  def quick_audit(metric)
    {
      overall_score: calculate_overall_quality_score(metric),
      level: determine_quality_level(metric),
      quick_checks: {
        completeness: calculate_completeness_score(metric),
        validity: calculate_validity_score(metric)
      }
    }
  end

  def detailed_audit(metric)
    comprehensive_audit(metric).merge(
      factor_breakdown: calculate_quality_factors(metric),
      historical_trends: monitor_quality_trends(metric),
      validation_details: validation_service.detailed_validation(metric)
    )
  end

  def calculate_trend(data)
    return :stable if data.size < 2

    first_half = data[0...data.size/2].sum / (data.size/2)
    second_half = data[data.size/2..-1].sum / (data.size - data.size/2)

    if second_half > first_half * 1.05
      :improving
    elsif second_half < first_half * 0.95
      :degrading
    else
      :stable
    end
  end

  def calculate_volatility(data)
    return 0.0 if data.size < 2

    mean = data.sum / data.size
    variance = data.sum { |x| (x - mean)**2 } / data.size
    Math.sqrt(variance) / mean
  end

  def generate_html_report(data)
    # Placeholder for HTML generation
    data.to_html
  end

  def generate_pdf_report(data)
    # Placeholder for PDF generation
    data.to_pdf
  end

  def cache_expiration(type)
    CACHE_EXPIRATION[type.to_sym] || 15.minutes
  end

  def handle_quality_error(error, metric)
    Rails.logger.error("Quality assessment failed for metric #{metric.id}: #{error.message}")
    # Implement fallback quality score
    { overall_score: 0.5, level: :poor, error: error.message }
  end
end