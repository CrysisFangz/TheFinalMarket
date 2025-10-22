# frozen_string_literal: true

# Refactored AnalyticsMetric model - now focused solely on data persistence
# Business logic extracted to dedicated services for improved modularity and maintainability
# Follows Clean Architecture principles with high cohesion and low coupling
#
# @author Kilo Code Autonomous Agent
# @version 3.0.0
# @since 2025-10-22
#
# @example
#   # Record metrics using the service layer
#   service = AnalyticsMetricService.new
#   service.record_realtime_metric(
#     name: :revenue,
#     value: 1000.0,
#     metric_type: :revenue,
#     dimensions: { channel: 'organic' }
#   )
#
#   # Calculate trends using the calculation service
#   calc_service = AnalyticsCalculationService.new
#   trend = calc_service.calculate_trend_analysis(metric, days: 30)
#
class AnalyticsMetric < ApplicationRecord
  include AnalyticsMetricConfiguration

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
  enum :aggregation_type, AGGREGATION_TYPES.index_by(&:to_s).transform_values(&:to_s)
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
    in: AGGREGATION_TYPES
  }
  validates :data_quality_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
                                  allow_nil: true

  # Conditional validations
  validate :value_within_reasonable_bounds, if: :value_present?
  validate :dimensions_schema_valid, if: :dimensions_present?
  validate :metadata_compliance, if: :metadata_present?

  # === CALLBACKS ===
  before_validation :set_defaults
  after_create :trigger_real_time_processing
  after_update :propagate_changes_to_aggregates, if: :significant_change?

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

  # === DELEGATED METHODS ===
  # Delegate business logic to services for separation of concerns

  # Service instances for delegation
  def service
    @service ||= AnalyticsMetricService.new
  end

  def calculation_service
    @calculation_service ||= AnalyticsCalculationService.new
  end

  def quality_service
    @quality_service ||= AnalyticsQualityService.new
  end

  def anomaly_service
    @anomaly_service ||= AnomalyDetectionService.new
  end

  def repository
    @repository ||= AnalyticsMetricRepository.new
  end

  # Delegated class methods
  def self.record_realtime_metric(name:, value:, metric_type:, dimensions: {}, metadata: {},
                                  source_system: nil, quality_score: nil)
    service = AnalyticsMetricService.new
    service.record_realtime_metric(
      name: name, value: value, metric_type: metric_type,
      dimensions: dimensions, metadata: metadata,
      source_system: source_system, quality_score: quality_score
    )
  end

  def self.record_batch_metrics(metrics_data:, batch_metadata: {})
    service = AnalyticsMetricService.new
    service.record_batch_metrics(metrics_data: metrics_data, batch_metadata: batch_metadata)
  end

  def self.get_metric_with_insights(metric_name:, date_range:, dimensions: {}, **options)
    service = AnalyticsMetricService.new
    service.get_metric_with_insights(
      metric_name: metric_name, date_range: date_range,
      dimensions: dimensions, **options
    )
  end

  def self.generate_analytics_report(report_type:, date_range:, dimensions: {},
                                     include_predictions: false, format: :json)
    service = AnalyticsMetricService.new
    service.generate_analytics_report(
      report_type: report_type, date_range: date_range,
      dimensions: dimensions, include_predictions: include_predictions,
      format: format
    )
  end

  # Delegated instance methods
  delegate :process_real_time_analytics, to: :service
  delegate :calculate_trend_analysis, :generate_predictive_forecast, to: :calculation_service
  delegate :detect_anomalies, :calculate_data_quality_score, :assess_data_quality, to: :quality_service
  delegate :calculate_statistical_insights, :calculate_derived_metrics, to: :calculation_service

  # === INSTANCE METHODS ===

  # Process real-time analytics pipeline (delegated)
  def process_real_time_analytics
    service.process_real_time_analytics(self)
  end

  # Calculate comprehensive trend analysis (delegated)
  def calculate_trend_analysis(days: 30, include_confidence: true)
    calculation_service.calculate_trend_analysis(self, days: days, include_confidence: include_confidence)
  end

  # Generate predictive forecast (delegated)
  def generate_predictive_forecast(horizon: 30.days, confidence_interval: 0.95)
    calculation_service.generate_predictive_forecast(self, horizon: horizon, confidence_interval: confidence_interval)
  end

  # Perform anomaly detection (delegated)
  def detect_anomalies(sensitivity: :medium)
    anomaly_service.detect_anomalies(self, sensitivity: sensitivity)
  end

  # Calculate data quality score (delegated)
  def calculate_data_quality_score
    quality_service.calculate_data_quality_score(self)
  end

  # Assess overall data quality (delegated)
  def assess_data_quality
    quality_service.assess_data_quality(self)
  end

  # Calculate statistical insights (delegated)
  def calculate_statistical_insights
    calculation_service.calculate_statistical_insights(self)
  end

  # Calculate derived metrics (delegated)
  def calculate_derived_metrics
    calculation_service.calculate_derived_metrics(self)
  end

  # === PRIVATE METHODS ===

  private

  # Set default values before validation
  def set_defaults
    self.date ||= Date.current
    self.aggregation_type ||= metric_type_config(metric_type)[:aggregation_type] if metric_type
    self.data_quality_score ||= 0.9
    self.anomaly_sensitivity ||= :medium
    self.dimensions_hash ||= generate_dimensions_hash(dimensions || {})
  end

  # Trigger real-time processing after creation
  def trigger_real_time_processing
    RealTimeProcessingJob.perform_later(id) if real_time_processing?
  end

  # Propagate changes to aggregates if significant
  def propagate_changes_to_aggregates
    return unless significant_change?

    AggregateUpdateJob.perform_later(id)
  end

  # Check if change is significant
  def significant_change?
    saved_change_to_value? && saved_change_to_value.first.present?
  end

  # Generate unique dimensions hash for efficient querying
  def generate_dimensions_hash(dimensions)
    return nil if dimensions.blank?

    Digest::SHA256.hexdigest(dimensions.to_json)
  end

  # Validate value within reasonable bounds
  def value_within_reasonable_bounds
    return unless value

    rule = validation_rule(:value_range)
    errors.add(:value, "must be between #{rule[:min]} and #{rule[:max]}") if value < rule[:min] || value > rule[:max]
  end

  # Validate dimensions schema
  def dimensions_schema_valid
    return unless dimensions

    # Add schema validation logic
    true
  end

  # Validate metadata compliance
  def metadata_compliance
    return unless metadata

    # Add compliance validation logic
    true
  end

  # Check if value is present
  def value_present?
    value.present?
  end

  # Check if dimensions are present
  def dimensions_present?
    dimensions.present?
  end

  # Check if metadata is present
  def metadata_present?
    metadata.present?
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
      category: metric_type_config(metric_type)[:category],
      unit: metric_type_config(metric_type)[:unit],
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
