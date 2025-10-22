# frozen_string_literal: true

# Configuration module for AnalyticsMetric constants and settings
# Extracted from the monolithic model to improve modularity and maintainability
# Follows Clean Architecture principles by separating configuration from business logic
module AnalyticsMetricConfiguration
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
      description: 'Total revenue generated',
      anomaly_detection: true,
      required_dimensions: [:channel, :device_type]
    },

    gross_revenue: {
      category: :financial,
      unit: :currency,
      aggregation_type: :sum,
      retention_period: 7.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:trend, :seasonality, :forecasting],
      description: 'Gross revenue before deductions',
      anomaly_detection: true,
      required_dimensions: [:channel]
    },

    net_revenue: {
      category: :financial,
      unit: :currency,
      aggregation_type: :sum,
      retention_period: 7.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:trend, :seasonality, :forecasting],
      description: 'Net revenue after deductions',
      anomaly_detection: true,
      required_dimensions: [:channel]
    },

    average_order_value: {
      category: :financial,
      unit: :currency,
      aggregation_type: :average,
      retention_period: 3.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:distribution, :segmentation],
      description: 'Average value per order',
      anomaly_detection: false,
      required_dimensions: [:customer_segment]
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
      description: 'Total number of customers',
      anomaly_detection: true,
      required_dimensions: [:geographic_region]
    },

    new_customers: {
      category: :customer,
      unit: :count,
      aggregation_type: :sum,
      retention_period: 5.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:cohort, :acquisition],
      description: 'New customers acquired',
      anomaly_detection: true,
      required_dimensions: [:channel]
    },

    customer_lifetime_value: {
      category: :customer,
      unit: :currency,
      aggregation_type: :average,
      retention_period: 5.years,
      real_time_processing: false,
      predictive_analytics: true,
      statistical_analysis: [:cohort, :segmentation, :forecasting],
      description: 'Predicted lifetime value per customer',
      anomaly_detection: false,
      required_dimensions: [:customer_segment]
    },

    customer_churn_rate: {
      category: :customer,
      unit: :percentage,
      aggregation_type: :average,
      retention_period: 3.years,
      real_time_processing: false,
      predictive_analytics: true,
      statistical_analysis: [:trend, :forecasting],
      description: 'Rate of customer churn',
      anomaly_detection: true,
      required_dimensions: []
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
      description: 'Product inventory levels',
      anomaly_detection: false,
      required_dimensions: [:product_category]
    },

    product_views: {
      category: :product,
      unit: :count,
      aggregation_type: :sum,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: false,
      statistical_analysis: [:trend, :popularity],
      description: 'Number of product views',
      anomaly_detection: false,
      required_dimensions: [:product_id]
    },

    product_conversion_rate: {
      category: :product,
      unit: :percentage,
      aggregation_type: :average,
      retention_period: 2.years,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:segmentation, :optimization],
      description: 'Product page to purchase conversion',
      anomaly_detection: true,
      required_dimensions: [:product_id]
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
      description: 'Website traffic volume',
      anomaly_detection: true,
      required_dimensions: [:source]
    },

    unique_visitors: {
      category: :traffic,
      unit: :count,
      aggregation_type: :sum,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: false,
      statistical_analysis: [:trend, :geographic],
      description: 'Unique visitors to platform',
      anomaly_detection: false,
      required_dimensions: [:geographic_region]
    },

    bounce_rate: {
      category: :traffic,
      unit: :percentage,
      aggregation_type: :average,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:segmentation, :optimization],
      description: 'Rate of single-page visits',
      anomaly_detection: true,
      required_dimensions: [:device_type]
    },

    session_duration: {
      category: :engagement,
      unit: :duration,
      aggregation_type: :average,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: false,
      statistical_analysis: [:distribution, :segmentation],
      description: 'Average session duration',
      anomaly_detection: false,
      required_dimensions: [:device_type]
    },

    page_views_per_session: {
      category: :engagement,
      unit: :count,
      aggregation_type: :average,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: false,
      statistical_analysis: [:distribution, :segmentation],
      description: 'Average pages viewed per session',
      anomaly_detection: false,
      required_dimensions: []
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
      description: 'Overall conversion rate',
      anomaly_detection: true,
      required_dimensions: [:channel]
    },

    cart_abandonment_rate: {
      category: :performance,
      unit: :percentage,
      aggregation_type: :average,
      retention_period: 1.year,
      real_time_processing: true,
      predictive_analytics: true,
      statistical_analysis: [:optimization, :segmentation],
      description: 'Rate of abandoned shopping carts',
      anomaly_detection: true,
      required_dimensions: [:device_type]
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
      description: 'Customer satisfaction scoring',
      anomaly_detection: false,
      required_dimensions: [:customer_segment]
    },

    net_promoter_score: {
      category: :experience,
      unit: :score,
      aggregation_type: :average,
      retention_period: 3.years,
      real_time_processing: false,
      predictive_analytics: true,
      statistical_analysis: [:segmentation, :trend],
      description: 'Net Promoter Score metric',
      anomaly_detection: false,
      required_dimensions: []
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
      description: 'Customer retention rate',
      anomaly_detection: true,
      required_dimensions: [:customer_segment]
    },

    repeat_purchase_rate: {
      category: :loyalty,
      unit: :percentage,
      aggregation_type: :average,
      retention_period: 3.years,
      real_time_processing: false,
      predictive_analytics: true,
      statistical_analysis: [:cohort, :segmentation],
      description: 'Rate of repeat purchases',
      anomaly_detection: false,
      required_dimensions: [:customer_segment]
    },

    customer_acquisition_cost: {
      category: :marketing,
      unit: :currency,
      aggregation_type: :average,
      retention_period: 3.years,
      real_time_processing: false,
      predictive_analytics: true,
      statistical_analysis: [:roi, :efficiency],
      description: 'Cost to acquire new customers',
      anomaly_detection: false,
      required_dimensions: [:channel]
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

  # Aggregation types for validation
  AGGREGATION_TYPES = %w[sum average count min max median].freeze

  # Quality factors for assessment
  QUALITY_FACTORS = %w[completeness accuracy timeliness consistency validity].freeze

  # Trend directions
  TREND_DIRECTIONS = %w[up down stable].freeze

  # Business cycle phases
  BUSINESS_CYCLE_PHASES = %w[expansion peak contraction trough].freeze

  # External correlation factors
  EXTERNAL_FACTORS = %w[market_trends economic_indicators seasonal_events].freeze

  # Cache expiration times for performance
  CACHE_EXPIRATION = {
    short: 15.minutes,
    medium: 1.hour,
    long: 1.day
  }.freeze

  # Batch processing thresholds
  BATCH_SIZE_THRESHOLD = 1000
  BATCH_PROCESSING_TIMEOUT = 5.minutes

  # Real-time processing latency targets (P99)
  REAL_TIME_LATENCY_TARGET = 10.milliseconds

  # Predictive model confidence thresholds
  PREDICTION_CONFIDENCE_THRESHOLD = 0.90

  # Anomaly detection parameters
  ANOMALY_DETECTION_WINDOW = 30.days
  ANOMALY_MIN_CONFIDENCE = 0.80

  # Statistical analysis parameters
  STATISTICAL_SIGNIFICANCE_LEVEL = 0.05
  MIN_SAMPLE_SIZE = 30

  # Performance optimization constants
  MAX_QUERY_COMPLEXITY = 5  # Max joins or subqueries
  INDEX_SCAN_THRESHOLD = 1000  # Use index scans for large datasets

  # Resilience and retry parameters
  MAX_RETRY_ATTEMPTS = 3
  RETRY_BACKOFF_BASE = 1.second
  CIRCUIT_BREAKER_THRESHOLD = 5
  CIRCUIT_BREAKER_TIMEOUT = 1.minute

  # Event sourcing parameters
  EVENT_RETENTION_PERIOD = 7.years
  SNAPSHOT_INTERVAL = 100  # Events before snapshot

  # Validation rules
  VALIDATION_RULES = {
    value_range: { min: -1e10, max: 1e10 },
    quality_score_range: { min: 0.0, max: 1.0 },
    date_range: { min: 10.years.ago, max: 1.year.from_now }
  }.freeze

  # Search and indexing parameters
  SEARCH_INDEX_REFRESH_INTERVAL = 1.hour
  SEARCH_HIGHLIGHT_FIELDS = %w[metric_name description].freeze

  # Reporting parameters
  REPORT_FORMATS = %w[json csv excel pdf].freeze
  MAX_REPORT_SIZE = 10000  # Records

  # Security and encryption parameters
  ENCRYPTION_ALGORITHM = 'AES-256-GCM'
  BLIND_INDEX_SALT = 'analytics_metric_blind_index_salt'

  # Monitoring and alerting parameters
  ALERT_COOLDOWN_PERIOD = 1.hour
  METRIC_UPDATE_FREQUENCY = 1.minute

  # Scalability parameters
  SHARD_COUNT = 4  # For horizontal scaling
  PARTITION_SIZE = 1.month  # For time-based partitioning

  # Internationalization parameters
  SUPPORTED_LOCALES = %w[en es fr de].freeze
  DEFAULT_LOCALE = 'en'.freeze

  # Accessibility parameters
  ACCESSIBILITY_STANDARDS = %w[WCAG_2.1 AA].freeze

  # Integration parameters
  EXTERNAL_API_TIMEOUT = 30.seconds
  API_RATE_LIMIT = 1000.requests_per_minute

  # Documentation and metadata
  API_VERSION = '2.0.0'
  DOCUMENTATION_URL = 'https://api.example.com/docs/analytics'

  # Feature flags for gradual rollout
  FEATURE_FLAGS = {
    real_time_processing: true,
    predictive_analytics: true,
    anomaly_detection: true,
    event_sourcing: false  # Gradual rollout
  }.freeze

  # Performance benchmarks
  BENCHMARK_TARGETS = {
    query_latency: 100.milliseconds,
    data_ingestion: 1.second,
    report_generation: 10.seconds,
    anomaly_detection: 5.seconds
  }.freeze

  # Error handling parameters
  ERROR_CATEGORIES = %w[validation processing network data_quality].freeze
  ERROR_RECOVERY_STRATEGIES = {
    transient: :retry_with_backoff,
    permanent: :dead_letter_queue,
    unknown: :circuit_breaker
  }.freeze

  # Logging levels
  LOG_LEVELS = %w[debug info warn error fatal].freeze
  DEFAULT_LOG_LEVEL = 'info'.freeze

  # Testing parameters
  TEST_COVERAGE_THRESHOLD = 95.0
  PERFORMANCE_TEST_THRESHOLD = 100.milliseconds

  # Deployment parameters
  DEPLOYMENT_ENVIRONMENTS = %w[development staging production].freeze
  ROLLBACK_TIMEOUT = 5.minutes

  # Compliance parameters
  COMPLIANCE_STANDARDS = %w[GDPR HIPAA SOX].freeze
  DATA_RETENTION_POLICIES = {
    personal_data: 2.years,
    financial_data: 7.years,
    analytics_data: 5.years
  }.freeze

  # Utility methods for configuration access
  def self.metric_type_config(type)
    METRIC_TYPES[type.to_sym] || raise(ArgumentError, "Unknown metric type: #{type}")
  end

  def self.quality_threshold(level)
    QUALITY_THRESHOLDS[level.to_sym] || raise(ArgumentError, "Unknown quality level: #{level}")
  end

  def self.anomaly_sensitivity(level)
    ANOMALY_SENSITIVITY[level.to_sym] || raise(ArgumentError, "Unknown sensitivity level: #{level}")
  end

  def self.valid_aggregation_type?(type)
    AGGREGATION_TYPES.include?(type)
  end

  def self.valid_trend_direction?(direction)
    TREND_DIRECTIONS.include?(direction)
  end

  def self.feature_enabled?(feature)
    FEATURE_FLAGS[feature.to_sym] || false
  end

  def self.benchmark_target(operation)
    BENCHMARK_TARGETS[operation.to_sym] || raise(ArgumentError, "Unknown benchmark: #{operation}")
  end

  def self.error_recovery_strategy(category)
    ERROR_RECOVERY_STRATEGIES[category.to_sym] || :unknown
  end

  def self.compliance_required?(standard)
    COMPLIANCE_STANDARDS.include?(standard)
  end

  def self.supported_locale?(locale)
    SUPPORTED_LOCALES.include?(locale)
  end

  def self.accessibility_standard?(standard)
    ACCESSIBILITY_STANDARDS.include?(standard)
  end

  def self.report_format_supported?(format)
    REPORT_FORMATS.include?(format)
  end

  def self.log_level_valid?(level)
    LOG_LEVELS.include?(level)
  end

  def self.deployment_environment?(env)
    DEPLOYMENT_ENVIRONMENTS.include?(env)
  end

  def self.data_retention_period(data_type)
    DATA_RETENTION_POLICIES[data_type.to_sym] || 5.years
  end

  def self.validation_rule(rule)
    VALIDATION_RULES[rule.to_sym] || raise(ArgumentError, "Unknown validation rule: #{rule}")
  end

  def self.search_highlight_field?(field)
    SEARCH_HIGHLIGHT_FIELDS.include?(field)
  end

  def self.external_factor?(factor)
    EXTERNAL_FACTORS.include?(factor)
  end

  def self.business_cycle_phase?(phase)
    BUSINESS_CYCLE_PHASES.include?(phase)
  end

  def self.quality_factor?(factor)
    QUALITY_FACTORS.include?(factor)
  end

  def self.error_category?(category)
    ERROR_CATEGORIES.include?(category)
  end

  def self.cache_expiration(type)
    CACHE_EXPIRATION[type.to_sym] || 15.minutes
  end

  def self.batch_size_threshold
    BATCH_SIZE_THRESHOLD
  end

  def self.batch_processing_timeout
    BATCH_PROCESSING_TIMEOUT
  end

  def self.real_time_latency_target
    REAL_TIME_LATENCY_TARGET
  end

  def self.prediction_confidence_threshold
    PREDICTION_CONFIDENCE_THRESHOLD
  end

  def self.anomaly_detection_window
    ANOMALY_DETECTION_WINDOW
  end

  def self.anomaly_min_confidence
    ANOMALY_MIN_CONFIDENCE
  end

  def self.statistical_significance_level
    STATISTICAL_SIGNIFICANCE_LEVEL
  end

  def self.min_sample_size
    MIN_SAMPLE_SIZE
  end

  def self.max_query_complexity
    MAX_QUERY_COMPLEXITY
  end

  def self.index_scan_threshold
    INDEX_SCAN_THRESHOLD
  end

  def self.max_retry_attempts
    MAX_RETRY_ATTEMPTS
  end

  def self.retry_backoff_base
    RETRY_BACKOFF_BASE
  end

  def self.circuit_breaker_threshold
    CIRCUIT_BREAKER_THRESHOLD
  end

  def self.circuit_breaker_timeout
    CIRCUIT_BREAKER_TIMEOUT
  end

  def self.event_retention_period
    EVENT_RETENTION_PERIOD
  end

  def self.snapshot_interval
    SNAPSHOT_INTERVAL
  end

  def self.encryption_algorithm
    ENCRYPTION_ALGORITHM
  end

  def self.blind_index_salt
    BLIND_INDEX_SALT
  end

  def self.alert_cooldown_period
    ALERT_COOLDOWN_PERIOD
  end

  def self.metric_update_frequency
    METRIC_UPDATE_FREQUENCY
  end

  def self.shard_count
    SHARD_COUNT
  end

  def self.partition_size
    PARTITION_SIZE
  end

  def self.default_locale
    DEFAULT_LOCALE
  end

  def self.api_version
    API_VERSION
  end

  def self.documentation_url
    DOCUMENTATION_URL
  end

  def self.test_coverage_threshold
    TEST_COVERAGE_THRESHOLD
  end

  def self.performance_test_threshold
    PERFORMANCE_TEST_THRESHOLD
  