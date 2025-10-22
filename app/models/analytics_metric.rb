# frozen_string_literal: true

# Enterprise-grade business intelligence and analytics metrics system with
# real-time processing, machine learning-powered predictive analytics,
# multi-dimensional data modeling, and advanced statistical analysis
#
# @author Kilo Code Autonomous Agent
# @version 2.0.0
# @since 2025-10-19
#
# @example
#   # Record sophisticated real-time metrics with multi-dimensional context
#   AnalyticsMetric.record_realtime_metric(
#     name: :revenue_per_visitor,
#     value: 45.67,
#     metric_type: :conversion,
#     dimensions: {
#       channel: 'organic_search',
#       device_type: 'mobile',
#       geographic_region: 'north_america',
#       customer_segment: 'premium',
#       time_of_day: 'business_hours'
#     },
#     metadata: {
#       confidence_level: 0.95,
#       data_quality_score: 0.98,
#       source_system: 'google_analytics',
#       calculation_method: 'weighted_average'
#     }
#   )
#
#   # Generate predictive insights with AI-powered forecasting
#   forecast = AnalyticsMetric.predictive_forecast(
#     metric_name: :monthly_revenue,
#     forecast_horizon: 90.days,
#     confidence_interval: 0.95,
#     include_seasonality: true,
#     include_external_factors: true
#   )
#
class AnalyticsMetric < ApplicationRecord
  # === CONSTANTS ===

  # Enhanced metric types with comprehensive metadata
  METRIC_TYPES = {
    # Revenue & Financial Metrics
    revenue: {
      category: :financial,
      unit: :currency,
      aggregation_type: :sum,
      retention_period: 7.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:trend, :seasonality, :forecasting],
      description: 'Total revenue generated'
    },

    gross_revenue: {
      category: :financial,
      unit: :currency,
      aggregation_type: :sum,
      retention_period: 7.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:trend, :seasonality, :forecasting],
      description: 'Gross revenue before deductions'
    },

    net_revenue: {
      category: :financial,
      unit: :currency,
      aggregation_type: :sum,
      retention_period: 7.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:trend, :seasonality, :forecasting],
      description: 'Net revenue after deductions'
    },

    average_order_value: {
      category: :financial,
      unit: :currency,
      aggregation_type: :average,
      retention_period: 3.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:distribution, :segmentation],
      description: 'Average value per order'
    },

    # Customer Metrics
    customers: {
      category: :customer,
      unit: :count,
      aggregation_type: :sum,
      retention_period: 5.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:cohort, :segmentation, :lifetime_value],
      description: 'Total number of customers'
    },

    new_customers: {
      category: :customer,
      unit: :count,
      aggregation_type: :sum,
      retention_period: 5.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:cohort, :acquisition],
      description: 'New customers acquired'
    },

    customer_lifetime_value: {
      category: :customer,
      unit: :currency,
      aggregation_type: :average,
      retention_period: 5.years,
      real_time_processing: false,
      predictive_analytics: true,
      statistical_analysis: [:cohort, :segmentation, :forecasting],
      description: 'Predicted lifetime value per customer'
    },

    customer_churn_rate: {
      category: :customer,
      unit: :percentage,
      aggregation_type: :average,
      retention_period: 3.years,
      real_time_processing: false,
      predictive_analytics: true,
      statistical_analysis: [:trend, :forecasting],
      description: 'Rate of customer churn'
    },

    # Product Metrics
    products: {
      category: :product,
      unit: :count,
      aggregation_type: :sum,
      retention_period: 3.years,
      real_time_processing: true,
      predictive_analytics: false,
      statistical_analysis: [:inventory, :demand],
      description: 'Product inventory levels'
    },

    product_views: {
      category: :product,
      unit: :count,
      aggregation_type: :sum,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: false,
      statistical_analysis: [:trend, :popularity],
      description: 'Number of product views'
    },

    product_conversion_rate: {
      category: :product,
      unit: :percentage,
      aggregation_type: :average,
      retention_period: 2.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:segmentation, :optimization],
      description: 'Product page to purchase conversion'
    },

    # Traffic & Engagement Metrics
    traffic: {
      category: :traffic,
      unit: :count,
      aggregation_type: :sum,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: false,
      statistical_analysis: [:trend, :sources],
      description: 'Website traffic volume'
    },

    unique_visitors: {
      category: :traffic,
      unit: :count,
      aggregation_type: :sum,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: false,
      statistical_analysis: [:trend, :geographic],
      description: 'Unique visitors to platform'
    },

    bounce_rate: {
      category: :traffic,
      unit: :percentage,
      aggregation_type: :average,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:segmentation, :optimization],
      description: 'Rate of single-page visits'
    },

    session_duration: {
      category: :engagement,
      unit: :duration,
      aggregation_type: :average,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: false,
      statistical_analysis: [:distribution, :segmentation],
      description: 'Average session duration'
    },

    page_views_per_session: {
      category: :engagement,
      unit: :count,
      aggregation_type: :average,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: false,
      statistical_analysis: [:distribution, :segmentation],
      description: 'Average pages viewed per session'
    },

    # Conversion & Performance Metrics
    conversion: {
      category: :performance,
      unit: :percentage,
      aggregation_type: :average,
      retention_period: 2.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:optimization, :segmentation],
      description: 'Overall conversion rate'
    },

    cart_abandonment_rate: {
      category: :performance,
      unit: :percentage,
      aggregation_type: :average,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:optimization, :segmentation],
      description: 'Rate of abandoned shopping carts'
    },

    # Advanced Analytics Metrics
    customer_satisfaction_score: {
      category: :experience,
      unit: :score,
      aggregation_type: :average,
      retention_period: 3.years,
      real_time_processing: false,
      predictive_analytics: true,
      statistical_analysis: [:sentiment, :correlation],
      description: 'Customer satisfaction scoring'
    },

    net_promoter_score: {
      category: :experience,
      unit: :score,
      aggregation_type: :average,
      retention_period: 3.years,
      real_time_processing: false,
      predictive_analytics: true,
      statistical_analysis: [:segmentation, :trend],
      description: 'Net Promoter Score metric'
    },

    # Retention & Loyalty Metrics
    retention: {
      category: :loyalty,
      unit: :percentage,
      aggregation_type: :average,
      retention_period: 5.years,
      real_time_processing: false,
      predictive_analytics: true,
      statistical_analysis: [:cohort, :lifetime_value],
      description: 'Customer retention rate'
    },

    repeat_purchase_rate: {
      category: :loyalty,
      unit: :percentage,
      aggregation_type: :average,
      retention_period: 3.years,
      real_time_processing: false,
      predictive_analytics: true,
      statistical_analysis: [:cohort, :segmentation],
      description: 'Rate of repeat purchases'
    },

    customer_acquisition_cost: {
      category: :marketing,
      unit: :currency,
      aggregation_type: :average,
      retention_period: 3.years,
      real_time_processing: false,
      predictive_analytics: true,
      statistical_analysis: [:roi, :efficiency],
      description: 'Cost to acquire new customers'
    }
  }.freeze

  # Data quality levels
  QUALITY_THRESHOLDS = {
    excellent: { min_score: 0.95, color: '#10B981' },
    good: { min_score: 0.85, color: '#3B82F6' },
    fair: { min_score: 0.70, color: '#F59E0B' },
    poor: { min_score: 0.50, color: '#EF4444' }
  }.freeze

  # Anomaly detection sensitivity levels
  ANOMALY_SENSITIVITY = {
    low: { standard_deviations: 2.0, false_positive_rate: 0.05 },
    medium: { standard_deviations: 2.5, false_positive_rate: 0.01 },
    high: { standard_deviations: 3.0, false_positive_rate: 0.001 }
  }.freeze

  # === ASSOCIATIONS ===
  # Multi-dimensional data relationships
  belongs_to :parent_metric, class_name: 'AnalyticsMetric', optional: true
  has_many :child_metrics, class_name: 'AnalyticsMetric',
           foreign_key: :parent_metric_id, dependent: :restrict_with_exception

  # Data lineage and provenance
  belongs_to :source_system, class_name: 'AnalyticsSource', optional: true
  has_many :data_lineage_records, class_name: 'AnalyticsDataLineage',
           dependent: :destroy

  # Quality and validation tracking
  has_many :quality_assessments, class_name: 'AnalyticsQualityAssessment',
           dependent: :destroy
  has_many :validation_rules, class_name: 'AnalyticsValidationRule',
           dependent: :destroy

  # Alert and notification relationships
  has_many :metric_alerts, class_name: 'AnalyticsAlert', dependent: :destroy
  has_many :anomaly_detections, class_name: 'AnalyticsAnomaly', dependent: :destroy

  # === ENCRYPTION & SECURITY ===
  encrypts :dimensions, :metadata, :statistical_data, deterministic: true
  blind_index :dimensions, :metadata

  # === ENUMS ===
  enum :metric_type, METRIC_TYPES.keys.index_by(&:to_s).transform_values(&:to_s)
  enum :aggregation_type, %w[sum average count min max median].index_by(&:to_s).transform_values(&:to_s)
  enum :data_quality_level, QUALITY_THRESHOLDS.keys.index_by(&:to_s).transform_values(&:to_s)
  enum :anomaly_sensitivity, ANOMALY_SENSITIVITY.keys.index_by(&:to_s).transform_values(&:to_s)

  # === VALIDATIONS ===
  validates :metric_name, presence: true, uniqueness: {
    scope: [:metric_type, :date, :dimensions_hash],
    message: 'Metric already exists for this date and dimensions'
  }
  validates :metric_type, presence: true, inclusion: { in: METRIC_TYPES.keys.map(&:to_s) }
  validates :date, presence: true
  validates :value, presence: true, numericality: { finite: true }
  validates :aggregation_type, presence: true, inclusion: {
    in: %w[sum average count min max median]
  }
  validates :data_quality_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
                                  allow_nil: true

  # Conditional validations
  validate :value_within_reasonable_bounds, if: :value_present?
  validate :dimensions_schema_valid, if: :dimensions_present?
  validate :metadata_compliance, if: :metadata_present?

  # === CALLBACKS ===
  before_validation :set_defaults, :calculate_derived_metrics, :enrich_analytics_data
  after_create :trigger_real_time_processing, :update_aggregate_metrics
  after_update :propagate_changes_to_aggregates, if: :significant_change?
  after_create :schedule_anomaly_detection, :update_predictive_models

  # === SCOPES ===
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :for_metric, ->(name) { where(metric_name: name) }
  scope :for_type, ->(type) { where(metric_type: type) }
  scope :recent, -> { where('date > ?', 30.days.ago) }

  # Advanced scopes for complex analytics
  scope :high_quality, -> { where('data_quality_score >= 0.85') }
  scope :low_quality, -> { where('data_quality_score < 0.70') }
  scope :real_time, -> { where(real_time_processing: true) }
  scope :batch_processed, -> { where(real_time_processing: false) }
  scope :predictive, -> { where(predictive_analytics_enabled: true) }
  scope :anomalous, -> { joins(:anomaly_detections).where(anomaly_detections: { status: :active }) }
  scope :trending_up, -> { where('trend_direction = ?', :up) }
  scope :trending_down, -> { where('trend_direction = ?', :down) }
  scope :with_alerts, -> { joins(:metric_alerts).where(metric_alerts: { active: true }) }

  # === CLASS METHODS ===

  # Enhanced metric recording with comprehensive metadata
  def self.record_realtime_metric(name:, value:, metric_type:, dimensions: {}, metadata: {},
                                  source_system: nil, quality_score: nil)
    transaction do
      # Create metric with enriched data
      metric = new(
        metric_name: name,
        value: value,
        metric_type: metric_type,
        dimensions: dimensions,
        metadata: metadata,
        source_system: source_system,
        data_quality_score: quality_score || calculate_data_quality(dimensions, metadata),
        aggregation_type: METRIC_TYPES[metric_type.to_sym][:aggregation_type],
        real_time_processing: true,
        dimensions_hash: generate_dimensions_hash(dimensions)
      )

      # Set date with time precision for real-time metrics
      metric.date = Time.current

      metric.save!

      # Trigger immediate processing
      metric.process_real_time_analytics

      metric
    end
  end

  # Batch metric recording for high-volume scenarios
  def self.record_batch_metrics(metrics_data:, batch_metadata: {})
    transaction do
      batch_id = generate_batch_id
      processed_metrics = []

      metrics_data.each do |metric_data|
        metric = create!(
          metric_data.merge(
            batch_id: batch_id,
            batch_metadata: batch_metadata,
            processed_at: Time.current
          )
        )
        processed_metrics << metric
      end

      # Process batch analytics
      process_batch_analytics(processed_metrics, batch_metadata)

      processed_metrics
    end
  end

  # Advanced metric retrieval with intelligent caching
  def self.get_metric_with_insights(metric_name:, date_range:, dimensions: {}, **options)
    Rails.cache.fetch(cache_key_for_metric(metric_name, date_range, dimensions), expires_in: 15.minutes) do
      # Retrieve base metrics
      metrics = retrieve_metrics_with_dimensions(metric_name, date_range, dimensions)

      # Enrich with derived insights
      enriched_metrics = enrich_metrics_with_insights(metrics, options)

      # Add predictive analytics if requested
      if options[:include_predictions]
        enriched_metrics = add_predictive_insights(enriched_metrics, options)
      end

      enriched_metrics
    end
  end

  # Generate comprehensive analytics report
  def self.generate_analytics_report(report_type:, date_range:, dimensions: {},
                                     include_predictions: false, format: :json)
    report_generator = AnalyticsReportGenerator.new(
      report_type: report_type,
      date_range: date_range,
      dimensions: dimensions,
      include_predictions: include_predictions
    )

    report_data = report_generator.generate

    case format.to_sym
    when :json then report_data.to_json
    when :csv then export_to_csv(report_data)
    when :excel then export_to_excel(report_data)
    else report_data
    end
  end

  # === INSTANCE METHODS ===

  # Process real-time analytics pipeline
  def process_real_time_analytics
    # Update real-time aggregations
    update_real_time_aggregations

    # Check for anomalies
    detect_anomalies if should_check_anomalies?

    # Trigger alerts if thresholds exceeded
    trigger_alerts_if_needed

    # Update predictive models
    update_predictive_models if predictive_analytics_enabled?
  end

  # Calculate comprehensive trend analysis
  def calculate_trend_analysis(days: 30, include_confidence: true)
    # Retrieve historical data
    historical_data = get_historical_data(days)

    # Perform statistical analysis
    trend_analysis = StatisticalAnalysisService.analyze_trend(
      data: historical_data,
      include_confidence: include_confidence
    )

    # Enrich with contextual insights
    enrich_trend_with_context(trend_analysis)
  end

  # Generate predictive forecast
  def generate_predictive_forecast(horizon: 30.days, confidence_interval: 0.95)
    return unless METRIC_TYPES[metric_type.to_sym][:predictive_analytics]

    # Prepare training data
    training_data = prepare_training_data(horizon * 2)

    # Train predictive model
    predictive_model = MachineLearningService.train_predictive_model(
      metric_name: metric_name,
      training_data: training_data,
      horizon: horizon,
      confidence_interval: confidence_interval
    )

    # Generate forecast
    forecast = predictive_model.generate_forecast

    # Enrich with business context
    enrich_forecast_with_context(forecast)
  end

  # Perform anomaly detection
  def detect_anomalies(sensitivity: :medium)
    anomaly_detector = AnomalyDetectionService.new(
      metric: self,
      sensitivity: sensitivity,
      historical_window: 30.days
    )

    anomalies = anomaly_detector.detect_anomalies

    # Record detected anomalies
    anomalies.each do |anomaly|
      anomaly_detections.create!(
        anomaly_type: anomaly[:type],
        severity: anomaly[:severity],
        confidence_score: anomaly[:confidence],
        detected_value: anomaly[:detected_value],
        expected_range: anomaly[:expected_range],
        detection_method: anomaly[:method]
      )
    end

    anomalies.any?
  end

  # Calculate data quality score
  def calculate_data_quality_score
    quality_factors = [
      completeness_score,
      accuracy_score,
      timeliness_score,
      consistency_score,
      validity_score
    ]

    # Weighted average of quality factors
    weights = [0.25, 0.25, 0.2, 0.15, 0.15]
    quality_score = quality_factors.zip(weights).sum { |factor, weight| factor * weight }

    # Update quality level
    self.data_quality_level = determine_quality_level(quality_score)
    self.data_quality_score = quality_score

    save! if changed?

    quality_score
  end

  # === PRIVATE METHODS ===

  private

  # Set default values before validation
  def set_defaults
    self.date ||= Date.current
    self.aggregation_type ||= METRIC_TYPES[metric_type.to_sym]&.dig(:aggregation_type) || 'sum'
    self.data_quality_score ||= 0.9
    self.anomaly_sensitivity ||= :medium
    self.dimensions_hash ||= generate_dimensions_hash(dimensions || {})
  end

  # Calculate derived metrics and enrich data
  def calculate_derived_metrics
    # Calculate statistical properties
    self.mean_value ||= calculate_mean_value
    self.standard_deviation ||= calculate_standard_deviation
    self.trend_direction ||= determine_trend_direction
    self.volatility_score ||= calculate_volatility_score

    # Calculate business-specific metrics
    case metric_type.to_sym
    when :conversion
      self.conversion_rate ||= calculate_conversion_rate
    when :customer_lifetime_value
      self.clv_score ||= calculate_clv_score
    when :bounce_rate
      self.engagement_score ||= calculate_engagement_score
    end
  end

  # Enrich analytics data with contextual information
  def enrich_analytics_data
    # Add seasonal context
    self.seasonal_factor ||= calculate_seasonal_factor

    # Add trend context
    self.trend_context ||= calculate_trend_context

    # Add business cycle context
    self.business_cycle_phase ||= determine_business_cycle_phase

    # Add external factor correlations
    self.external_correlations ||= calculate_external_correlations
  end

  # Update real-time aggregations
  def update_real_time_aggregations
    # Update hourly aggregations
    update_hourly_aggregation

    # Update daily aggregations
    update_daily_aggregation

    # Update rolling averages
    update_rolling_averages

    # Update trend indicators
    update_trend_indicators
  end

  # Generate unique dimensions hash for efficient querying
  def generate_dimensions_hash(dimensions)
    return nil if dimensions.blank?

    Digest::SHA256.hexdigest(dimensions.to_json)
  end

  # Retrieve metrics with dimensional filtering
  def self.retrieve_metrics_with_dimensions(metric_name, date_range, dimensions)
    query = for_metric(metric_name).for_date_range(date_range.begin, date_range.end)

    # Apply dimensional filters
    dimensions.each do |key, value|
      query = query.where("dimensions->>? = ?", key.to_s, value.to_s)
    end

    query.order(date: :asc).to_a
  end

  # Enrich metrics with advanced insights
  def self.enrich_metrics_with_insights(metrics, options)
    enriched_metrics = []

    metrics.each do |metric|
      enriched_metric = metric.as_json

      # Add statistical insights
      enriched_metric['statistical_insights'] = metric.calculate_statistical_insights

      # Add trend analysis
      enriched_metric['trend_analysis'] = metric.calculate_trend_analysis(
        days: options[:trend_window] || 30
      )

      # Add quality assessment
      enriched_metric['quality_assessment'] = metric.assess_data_quality

      # Add anomaly status
      enriched_metric['anomaly_status'] = metric.current_anomaly_status

      enriched_metrics << enriched_metric
    end

    enriched_metrics
  end

  # Add predictive insights to metrics
  def self.add_predictive_insights(metrics, options)
    metrics.each do |metric|
      metric['predictive_forecast'] = metric.generate_predictive_forecast(
        horizon: options[:forecast_horizon] || 30.days,
        confidence_interval: options[:confidence_interval] || 0.95
      )
    end

    metrics
  end

  # === STATISTICAL ANALYSIS METHODS ===

  # Calculate mean value for metric
  def calculate_mean_value
    return value unless parent_metric

    # Calculate weighted mean from child metrics
    child_metrics.average(:value)
  end

  # Calculate standard deviation
  def calculate_standard_deviation
    return 0.0 unless parent_metric

    values = child_metrics.pluck(:value)
    StatisticalAnalysisService.standard_deviation(values)
  end

  # Determine trend direction
  def determine_trend_direction
    return :stable unless parent_metric

    trend_analysis = calculate_trend_analysis(days: 7)
    trend_analysis[:direction]
  end

  # Calculate volatility score
  def calculate_volatility_score
    return 0.1 unless standard_deviation && mean_value

    # Coefficient of variation
    (standard_deviation / mean_value.abs) * 100
  end

  # Calculate seasonal factor
  def calculate_seasonal_factor
    SeasonalAnalysisService.calculate_seasonal_factor(
      metric_name: metric_name,
      date: date
    )
  end

  # Determine business cycle phase
  def determine_business_cycle_phase
    BusinessCycleService.determine_phase(
      metric_type: metric_type,
      date: date,
      value: value
    )
  end

  # === QUALITY ASSESSMENT METHODS ===

  # Assess overall data quality
  def assess_data_quality
    {
      overall_score: data_quality_score,
      level: data_quality_level,
      factors: {
        completeness: completeness_score,
        accuracy: accuracy_score,
        timeliness: timeliness_score,
        consistency: consistency_score,
        validity: validity_score
      },
      recommendations: quality_improvement_recommendations,
      last_assessed: quality_assessments.last&.created_at
    }
  end

  # Calculate completeness score
  def completeness_score
    required_fields = METRIC_TYPES[metric_type.to_sym][:required_dimensions] || []
    provided_fields = dimensions&.keys || []

    return 1.0 if required_fields.empty?

    (provided_fields & required_fields).count.to_f / required_fields.count
  end

  # Calculate accuracy score based on validation rules
  def accuracy_score
    validation_results = validate_against_rules
    valid_results = validation_results.count { |result| result[:valid] }

    valid_results.to_f / validation_results.count
  end

  # Calculate timeliness score
  def timeliness_score
    return 1.0 unless real_time_processing?

    # Score based on how recently data was processed
    hours_old = ((Time.current - processed_at) / 1.hour).to_f
    [1.0 - (hours_old * 0.1), 0.0].max
  end

  # === ANOMALY DETECTION ===

  # Check if metric should be analyzed for anomalies
  def should_check_anomalies?
    METRIC_TYPES[metric_type.to_sym][:anomaly_detection] || false
  end

  # Trigger alerts based on configured thresholds
  def trigger_alerts_if_needed
    metric_alerts.active.each do |alert|
      if alert.threshold_exceeded?(value)
        alert.trigger!(current_value: value, metric: self)
      end
    end
  end

  # Get current anomaly status
  def current_anomaly_status
    active_anomalies = anomaly_detections.where(status: :active)

    {
      has_anomalies: active_anomalies.any?,
      anomaly_count: active_anomalies.count,
      latest_anomaly: active_anomalies.order(created_at: :desc).first,
      severity_breakdown: active_anomalies.group(:severity).count
    }
  end

  # === PERFORMANCE OPTIMIZATIONS ===

  # Generate cache key for metric queries
  def self.cache_key_for_metric(metric_name, date_range, dimensions)
    dimensions_hash = generate_dimensions_hash(dimensions)
    "analytics_metric:#{metric_name}:#{date_range.begin}:#{date_range.end}:#{dimensions_hash}"
  end

  # Generate unique batch ID
  def self.generate_batch_id
    "batch_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
  end

  # === SEARCH & ANALYTICS ===

  # Elasticsearch integration for advanced search
  searchkick mappings: {
    metric_name: { type: :keyword },
    metric_type: { type: :keyword },
    date: { type: :date },
    value: { type: :float },
    dimensions: { type: :object },
    data_quality_score: { type: :float },
    trend_direction: { type: :keyword },
    anomaly_sensitivity: { type: :keyword }
  }

  def search_data
    {
      metric_name: metric_name,
      metric_type: metric_type,
      date: date,
      value: value,
      dimensions: dimensions,
      data_quality_score: data_quality_score,
      trend_direction: trend_direction,
      category: METRIC_TYPES[metric_type.to_sym][:category],
      unit: METRIC_TYPES[metric_type.to_sym][:unit],
      aggregation_type: aggregation_type
    }
  end

  # === DATABASE OPTIMIZATIONS ===

  # Performance-optimized database indexes
  self.primary_key = :id

  # Composite indexes for common query patterns
  index :date
  index [:metric_name, :date]
  index [:metric_type, :date]
  index [:metric_name, :metric_type, :date]
  index [:data_quality_score, :date]
  index [:trend_direction, :date]
  index [:dimensions_hash, :date]

  # Partial indexes for specific use cases
  index :value, where: "real_time_processing = true"
  index :batch_id, where: "batch_id IS NOT NULL"
  index :parent_metric_id, where: "parent_metric_id IS NOT NULL"

  # Partitioning for large datasets (implemented via database views)
  scope :current_partition, -> { where('date >= ?', Date.current.beginning_of_month) }
  scope :previous_partition, -> { where('date >= ?', 1.month.ago.beginning_of_month) }
end
