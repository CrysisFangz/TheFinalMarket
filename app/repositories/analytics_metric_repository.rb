# frozen_string_literal: true

# Repository class for AnalyticsMetric data access
# Extracted from the monolithic model to implement Repository Pattern
# Provides a clean interface for data operations, enabling easy testing and swapping of data sources
class AnalyticsMetricRepository
  include AnalyticsMetricConfiguration

  # Retrieve metrics with dimensional filtering
  def retrieve_metrics_with_dimensions(metric_name, date_range, dimensions)
    query = base_query(metric_name, date_range)

    # Apply dimensional filters
    dimensions.each do |key, value|
      query = query.where("dimensions->>? = ?", key.to_s, value.to_s)
    end

    query.order(date: :asc).to_a
  end

  # Get historical data for a metric
  def get_historical_data(metric, days)
    AnalyticsMetric.where(metric_name: metric.metric_name)
                   .where('date >= ?', days.ago)
                   .order(date: :asc)
                   .pluck(:value)
  end

  # Find metrics by name and date range
  def find_by_name_and_date_range(metric_name, start_date, end_date)
    AnalyticsMetric.where(metric_name: metric_name)
                   .where(date: start_date..end_date)
                   .order(date: :asc)
  end

  # Find metrics by type and date range
  def find_by_type_and_date_range(metric_type, start_date, end_date)
    AnalyticsMetric.where(metric_type: metric_type)
                   .where(date: start_date..end_date)
                   .order(date: :asc)
  end

  # Find metrics with high quality scores
  def find_high_quality_metrics(date_range)
    AnalyticsMetric.where('data_quality_score >= 0.85')
                   .where(date: date_range)
                   .order(date: :asc)
  end

  # Find anomalous metrics
  def find_anomalous_metrics
    AnalyticsMetric.joins(:anomaly_detections)
                   .where(anomaly_detections: { status: :active })
                   .distinct
  end

  # Find trending metrics
  def find_trending_metrics(direction, date_range)
    AnalyticsMetric.where('trend_direction = ?', direction)
                   .where(date: date_range)
                   .order(date: :asc)
  end

  # Find metrics with alerts
  def find_metrics_with_alerts
    AnalyticsMetric.joins(:metric_alerts)
                   .where(metric_alerts: { active: true })
                   .distinct
  end

  # Aggregate metrics by time period
  def aggregate_by_period(metric_name, period, start_date, end_date)
    case period.to_sym
    when :hour
      group_by_hour(metric_name, start_date, end_date)
    when :day
      group_by_day(metric_name, start_date, end_date)
    when :week
      group_by_week(metric_name, start_date, end_date)
    when :month
      group_by_month(metric_name, start_date, end_date)
    else
      raise ArgumentError, "Unknown period: #{period}"
    end
  end

  # Get metrics for batch processing
  def get_batch_metrics(batch_id)
    AnalyticsMetric.where(batch_id: batch_id)
                   .order(created_at: :asc)
  end

  # Get real-time metrics
  def get_real_time_metrics
    AnalyticsMetric.where(real_time_processing: true)
                   .where('date >= ?', 1.hour.ago)
                   .order(date: :desc)
  end

  # Get predictive metrics
  def get_predictive_metrics
    AnalyticsMetric.where(predictive_analytics_enabled: true)
                   .order(date: :desc)
  end

  # Search metrics using Elasticsearch
  def search_metrics(query, filters = {})
    search_definition = {
      query: {
        bool: {
          must: [
            {
              multi_match: {
                query: query,
                fields: %w[metric_name description]
              }
            }
          ]
        }
      }
    }

    # Add filters
    if filters[:metric_type]
      search_definition[:query][:bool][:filter] ||= []
      search_definition[:query][:bool][:filter] << {
        term: { metric_type: filters[:metric_type] }
      }
    end

    if filters[:date_range]
      search_definition[:query][:bool][:filter] ||= []
      search_definition[:query][:bool][:filter] << {
        range: {
          date: {
            gte: filters[:date_range].begin,
            lte: filters[:date_range].end
          }
        }
      }
    end

    if filters[:dimensions]
      filters[:dimensions].each do |key, value|
        search_definition[:query][:bool][:filter] ||= []
        search_definition[:query][:bool][:filter] << {
          term: { "dimensions.#{key}" => value }
        }
      end
    end

    AnalyticsMetric.search(search_definition).records
  end

  # Get metrics for reporting
  def get_metrics_for_report(report_type, date_range, dimensions = {})
    case report_type.to_sym
    when :summary
      get_summary_metrics(date_range, dimensions)
    when :detailed
      get_detailed_metrics(date_range, dimensions)
    when :predictive
      get_predictive_metrics_for_report(date_range, dimensions)
    else
      raise ArgumentError, "Unknown report type: #{report_type}"
    end
  end

  # Save metric with validation
  def save_metric(metric)
    metric.save!
    metric
  rescue ActiveRecord::RecordInvalid => e
    raise ValidationError, e.message
  end

  # Update metric
  def update_metric(metric, attributes)
    metric.update!(attributes)
    metric
  rescue ActiveRecord::RecordInvalid => e
    raise ValidationError, e.message
  end

  # Delete metric
  def delete_metric(metric)
    metric.destroy!
  end

  # Bulk insert metrics
  def bulk_insert_metrics(metrics_data)
    AnalyticsMetric.insert_all(metrics_data)
  rescue ActiveRecord::StatementInvalid => e
    raise BulkInsertError, e.message
  end

  # Get metrics count
  def count_metrics(filters = {})
    query = AnalyticsMetric.all

    query = query.where(metric_name: filters[:metric_name]) if filters[:metric_name]
    query = query.where(metric_type: filters[:metric_type]) if filters[:metric_type]
    query = query.where('date >= ?', filters[:start_date]) if filters[:start_date]
    query = query.where('date <= ?', filters[:end_date]) if filters[:end_date]

    query.count
  end

  # Get metrics statistics
  def get_metrics_statistics(metric_name, date_range)
    metrics = find_by_name_and_date_range(metric_name, date_range.begin, date_range.end)

    values = metrics.pluck(:value)

    {
      count: values.count,
      sum: values.sum,
      average: values.sum / values.count.to_f,
      min: values.min,
      max: values.max,
      standard_deviation: calculate_standard_deviation(values)
    }
  rescue StandardError => e
    { error: e.message }
  end

  # Get top performing metrics
  def get_top_performing_metrics(limit = 10, date_range)
    AnalyticsMetric.where(date: date_range)
                   .order(value: :desc)
                   .limit(limit)
  end

  # Get low performing metrics
  def get_low_performing_metrics(limit = 10, date_range)
    AnalyticsMetric.where(date: date_range)
                   .order(value: :asc)
                   .limit(limit)
  end

  # Get metrics by category
  def get_metrics_by_category(category, date_range)
    metric_types = metric_type_config.select { |_, config| config[:category] == category }.keys

    AnalyticsMetric.where(metric_type: metric_types)
                   .where(date: date_range)
                   .order(date: :asc)
  end

  # Get metrics with specific dimensions
  def get_metrics_with_dimensions(dimensions, date_range)
    query = AnalyticsMetric.where(date: date_range)

    dimensions.each do |key, value|
      query = query.where("dimensions->>? = ?", key.to_s, value.to_s)
    end

    query.order(date: :asc)
  end

  # Get metrics for anomaly detection
  def get_metrics_for_anomaly_detection(metric_name, window)
    AnalyticsMetric.where(metric_name: metric_name)
                   .where('date >= ?', window.ago)
                   .order(date: :asc)
                   .pluck(:value, :date)
  end

  # Get metrics for trend analysis
  def get_metrics_for_trend_analysis(metric_name, window)
    AnalyticsMetric.where(metric_name: metric_name)
                   .where('date >= ?', window.ago)
                   .order(date: :asc)
                   .pluck(:value, :date)
  end

  # Get metrics for forecasting
  def get_metrics_for_forecasting(metric_name, window)
    AnalyticsMetric.where(metric_name: metric_name)
                   .where('date >= ?', window.ago)
                   .order(date: :asc)
                   .pluck(:value, :date, :dimensions)
  end

  # Get metrics for quality assessment
  def get_metrics_for_quality_assessment(date_range)
    AnalyticsMetric.where(date: date_range)
                   .includes(:quality_assessments)
                   .order(date: :asc)
  end

  # Get metrics for validation
  def get_metrics_for_validation(metric_type, date_range)
    AnalyticsMetric.where(metric_type: metric_type)
                   .where(date: date_range)
                   .includes(:validation_rules)
                   .order(date: :asc)
  end

  # Get metrics for lineage tracking
  def get_metrics_for_lineage(metric_id)
    AnalyticsMetric.find(metric_id).data_lineage_records
  end

  # Get metrics for provenance
  def get_metrics_for_provenance(source_system_id)
    AnalyticsMetric.where(source_system_id: source_system_id)
                   .order(date: :asc)
  end

  # Get metrics for alerting
  def get_metrics_for_alerting
    AnalyticsMetric.joins(:metric_alerts)
                   .where(metric_alerts: { active: true })
                   .distinct
  end

  # Get metrics for caching
  def get_metrics_for_caching(cache_key)
    # Implementation for cache-based retrieval
    Rails.cache.fetch(cache_key, expires_in: cache_expiration(:short)) do
      # Default implementation
      []
    end
  end

  private

  def base_query(metric_name, date_range)
    AnalyticsMetric.where(metric_name: metric_name)
                   .where(date: date_range.begin..date_range.end)
  end

  def group_by_hour(metric_name, start_date, end_date)
    AnalyticsMetric.where(metric_name: metric_name)
                   .where(date: start_date..end_date)
                   .group("DATE_TRUNC('hour', date)")
                   .sum(:value)
  end

  def group_by_day(metric_name, start_date, end_date)
    AnalyticsMetric.where(metric_name: metric_name)
                   .where(date: start_date..end_date)
                   .group("DATE_TRUNC('day', date)")
                   .sum(:value)
  end

  def group_by_week(metric_name, start_date, end_date)
    AnalyticsMetric.where(metric_name: metric_name)
                   .where(date: start_date..end_date)
                   .group("DATE_TRUNC('week', date)")
                   .sum(:value)
  end

  def group_by_month(metric_name, start_date, end_date)
    AnalyticsMetric.where(metric_name: metric_name)
                   .where(date: start_date..end_date)
                   .group("DATE_TRUNC('month', date)")
                   .sum(:value)
  end

  def get_summary_metrics(date_range, dimensions)
    query = AnalyticsMetric.where(date: date_range)

    dimensions.each do |key, value|
      query = query.where("dimensions->>? = ?", key.to_s, value.to_s)
    end

    query.group(:metric_name).sum(:value)
  end

  def get_detailed_metrics(date_range, dimensions)
    query = AnalyticsMetric.where(date: date_range)

    dimensions.each do |key, value|
      query = query.where("dimensions->>? = ?", key.to_s, value.to_s)
    end

    query.order(date: :asc)
  end

  def get_predictive_metrics_for_report(date_range, dimensions)
    query = AnalyticsMetric.where(date: date_range)
                           .where(predictive_analytics_enabled: true)

    dimensions.each do |key, value|
      query = query.where("dimensions->>? = ?", key.to_s, value.to_s)
    end

    query.order(date: :asc)
  end

  def calculate_standard_deviation(values)
    return 0.0 if values.empty?

    mean = values.sum / values.count.to_f
    variance = values.sum { |value| (value - mean)**2 } / values.count.to_f
    Math.sqrt(variance)
  end

  def cache_expiration(type)
    CACHE_EXPIRATION[type.to_sym] || 15.minutes
  end

  # Custom error classes
  class ValidationError < StandardError; end
  class BulkInsertError < StandardError; end
end