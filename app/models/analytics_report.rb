# frozen_string_literal: true

# Enterprise-grade business intelligence reporting platform with
# advanced report generation, intelligent scheduling, real-time streaming,
# multi-format exports, and collaborative features
#
# @author Kilo Code Autonomous Agent
# @version 2.0.0
# @since 2025-10-19
#
# @example
#   # Create sophisticated executive dashboard with real-time streaming
#   dashboard = AnalyticsReport.create_executive_dashboard(
#     user: ceo_user,
#     title: "Executive Performance Dashboard",
#     data_sources: [:revenue, :customer_metrics, :product_performance],
#     refresh_interval: 5.minutes,
#     real_time_updates: true,
#     ai_insights: true,
#     collaborative_features: true,
#     distribution_channels: [:email, :slack, :mobile_app]
#   )
#
#   # Generate predictive analytics report with AI-powered insights
#   forecast_report = AnalyticsReport.generate_predictive_report(
#     report_type: :revenue_forecast,
#     forecast_horizon: 90.days,
#     confidence_interval: 0.95,
#     include_external_factors: true,
#     include_recommendations: true,
#     target_audience: :executive_team
#   )
#
class AnalyticsReport < ApplicationRecord
  # === CONSTANTS ===

  # Enhanced report types with comprehensive metadata
  REPORT_TYPES = {
    # Financial Reports
    revenue_report: {
      category: :finance,
      complexity: :high,
      data_volume: :large,
      processing_time: :medium,
      real_time_capable: true,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :csv, :json],
      required_permissions: [:finance_read],
      caching_strategy: :aggressive,
      description: 'Comprehensive revenue analysis and trends'
    },

    sales_report: {
      category: :sales,
      complexity: :medium,
      data_volume: :large,
      processing_time: :medium,
      real_time_capable: true,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :csv, :json, :powerpoint],
      required_permissions: [:sales_read],
      caching_strategy: :moderate,
      description: 'Detailed sales performance and metrics'
    },

    profit_loss_report: {
      category: :finance,
      complexity: :high,
      data_volume: :medium,
      processing_time: :high,
      real_time_capable: false,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :json],
      required_permissions: [:finance_read, :executive_access],
      caching_strategy: :conservative,
      description: 'Profit and loss analysis with forecasting'
    },

    # Customer Analytics
    customer_report: {
      category: :customer,
      complexity: :medium,
      data_volume: :large,
      processing_time: :medium,
      real_time_capable: true,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :csv, :json],
      required_permissions: [:customer_read],
      caching_strategy: :moderate,
      description: 'Customer behavior and segmentation analysis'
    },

    cohort_report: {
      category: :customer,
      complexity: :high,
      data_volume: :large,
      processing_time: :high,
      real_time_capable: false,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :csv, :json],
      required_permissions: [:analytics_read],
      caching_strategy: :conservative,
      description: 'Cohort analysis with lifetime value predictions'
    },

    customer_lifetime_value: {
      category: :customer,
      complexity: :high,
      data_volume: :medium,
      processing_time: :high,
      real_time_capable: false,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :json],
      required_permissions: [:analytics_read],
      caching_strategy: :conservative,
      description: 'Customer lifetime value modeling and predictions'
    },

    # Product Analytics
    product_report: {
      category: :product,
      complexity: :medium,
      data_volume: :large,
      processing_time: :medium,
      real_time_capable: true,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :csv, :json],
      required_permissions: [:product_read],
      caching_strategy: :moderate,
      description: 'Product performance and inventory analysis'
    },

    market_basket: {
      category: :product,
      complexity: :high,
      data_volume: :large,
      processing_time: :high,
      real_time_capable: false,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :csv, :json],
      required_permissions: [:analytics_read],
      caching_strategy: :conservative,
      description: 'Market basket analysis and product recommendations'
    },

    product_performance: {
      category: :product,
      complexity: :medium,
      data_volume: :medium,
      processing_time: :medium,
      real_time_capable: true,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :csv, :json],
      required_permissions: [:product_read],
      caching_strategy: :moderate,
      description: 'Individual product performance metrics'
    },

    # Traffic & Marketing
    traffic_report: {
      category: :marketing,
      complexity: :medium,
      data_volume: :large,
      processing_time: :medium,
      real_time_capable: true,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :csv, :json],
      required_permissions: [:marketing_read],
      caching_strategy: :moderate,
      description: 'Website traffic analysis and sources'
    },

    conversion_report: {
      category: :marketing,
      complexity: :high,
      data_volume: :large,
      processing_time: :medium,
      real_time_capable: true,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :csv, :json, :powerpoint],
      required_permissions: [:marketing_read, :analytics_read],
      caching_strategy: :moderate,
      description: 'Conversion funnel analysis and optimization'
    },

    campaign_performance: {
      category: :marketing,
      complexity: :high,
      data_volume: :medium,
      processing_time: :medium,
      real_time_capable: true,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :csv, :json, :powerpoint],
      required_permissions: [:marketing_read],
      caching_strategy: :moderate,
      description: 'Marketing campaign performance and ROI'
    },

    # Operational Reports
    operational_report: {
      category: :operations,
      complexity: :medium,
      data_volume: :medium,
      processing_time: :medium,
      real_time_capable: true,
      ai_enhanced: false,
      export_formats: [:pdf, :excel, :csv, :json],
      required_permissions: [:operations_read],
      caching_strategy: :moderate,
      description: 'Operational metrics and efficiency analysis'
    },

    inventory_report: {
      category: :operations,
      complexity: :medium,
      data_volume: :large,
      processing_time: :medium,
      real_time_capable: true,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :csv, :json],
      required_permissions: [:inventory_read],
      caching_strategy: :moderate,
      description: 'Inventory levels and turnover analysis'
    },

    # Executive Dashboards
    executive_dashboard: {
      category: :executive,
      complexity: :very_high,
      data_volume: :large,
      processing_time: :high,
      real_time_capable: true,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :powerpoint, :interactive_html],
      required_permissions: [:executive_access],
      caching_strategy: :aggressive,
      description: 'Executive-level business performance overview'
    },

    kpi_dashboard: {
      category: :executive,
      complexity: :high,
      data_volume: :medium,
      processing_time: :medium,
      real_time_capable: true,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :powerpoint, :interactive_html],
      required_permissions: [:executive_access],
      caching_strategy: :aggressive,
      description: 'Key Performance Indicators dashboard'
    },

    # Custom & Advanced Analytics
    custom_query: {
      category: :custom,
      complexity: :variable,
      data_volume: :variable,
      processing_time: :variable,
      real_time_capable: false,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :csv, :json, :xml],
      required_permissions: [:custom_reports],
      caching_strategy: :conservative,
      description: 'Custom query-based reports'
    },

    predictive_analytics: {
      category: :advanced,
      complexity: :very_high,
      data_volume: :large,
      processing_time: :very_high,
      real_time_capable: false,
      ai_enhanced: true,
      export_formats: [:pdf, :excel, :json, :interactive_html],
      required_permissions: [:predictive_analytics],
      caching_strategy: :conservative,
      description: 'AI-powered predictive analytics reports'
    }
  }.freeze

  # Report categories with hierarchical structure
  REPORT_CATEGORIES = {
    executive: {
      priority: :highest,
      access_level: :restricted,
      refresh_frequency: :real_time,
      distribution: :automated,
      description: 'Executive-level strategic reports'
    },
    finance: {
      priority: :high,
      access_level: :restricted,
      refresh_frequency: :hourly,
      distribution: :automated,
      description: 'Financial performance and analysis'
    },
    sales: {
      priority: :high,
      access_level: :standard,
      refresh_frequency: :real_time,
      distribution: :automated,
      description: 'Sales performance and pipeline'
    },
    marketing: {
      priority: :medium,
      access_level: :standard,
      refresh_frequency: :hourly,
      distribution: :automated,
      description: 'Marketing performance and campaigns'
    },
    customer: {
      priority: :medium,
      access_level: :standard,
      refresh_frequency: :daily,
      distribution: :on_demand,
      description: 'Customer analytics and insights'
    },
    product: {
      priority: :medium,
      access_level: :standard,
      refresh_frequency: :daily,
      distribution: :on_demand,
      description: 'Product performance and analytics'
    },
    operations: {
      priority: :medium,
      access_level: :standard,
      refresh_frequency: :hourly,
      distribution: :automated,
      description: 'Operational efficiency and metrics'
    },
    custom: {
      priority: :low,
      access_level: :variable,
      refresh_frequency: :manual,
      distribution: :on_demand,
      description: 'Custom and ad-hoc reports'
    }
  }.freeze

  # Execution priority levels
  PRIORITY_LEVELS = {
    critical: { queue_priority: 100, timeout: 30.minutes },
    high: { queue_priority: 75, timeout: 15.minutes },
    medium: { queue_priority: 50, timeout: 10.minutes },
    low: { queue_priority: 25, timeout: 5.minutes }
  }.freeze

  # === ASSOCIATIONS ===
  belongs_to :user, inverse_of: :analytics_reports
  belongs_to :organization, optional: true

  # Report lifecycle management
  has_many :report_schedules, dependent: :destroy, inverse_of: :analytics_report
  has_many :report_executions, dependent: :destroy, inverse_of: :analytics_report

  # Data source relationships
  has_many :report_data_sources, dependent: :destroy, inverse_of: :analytics_report
  has_many :data_sources, through: :report_data_sources

  # Collaboration features
  has_many :report_shares, dependent: :destroy, inverse_of: :analytics_report
  has_many :shared_with_users, through: :report_shares, source: :user

  # Version control and history
  has_many :report_versions, dependent: :destroy, inverse_of: :analytics_report
  belongs_to :parent_version, class_name: 'AnalyticsReport', optional: true

  # Comments and annotations
  has_many :report_comments, dependent: :destroy, inverse_of: :analytics_report

  # Security and access control
  has_many :report_permissions, dependent: :destroy, inverse_of: :analytics_report
  has_many :access_logs, class_name: 'ReportAccessLog', dependent: :destroy

  # === ENCRYPTION & SECURITY ===
  encrypts :query_parameters, :custom_query, :sensitive_data, deterministic: true
  encrypts :report_metadata, :configuration, deterministic: true
  blind_index :query_parameters, :custom_query

  # === ENUMS ===
  enum :report_type, REPORT_TYPES.keys.index_by(&:to_s).transform_values(&:to_s)
  enum :category, REPORT_CATEGORIES.keys.index_by(&:to_s).transform_values(&:to_s)
  enum :priority, PRIORITY_LEVELS.keys.index_by(&:to_s).transform_values(&:to_s)
  enum :status, %w[draft active inactive archived].index_by(&:to_s).transform_values(&:to_s)
  enum :distribution_method, %w[email slack webhook api mobile_push].index_by(&:to_s).transform_values(&:to_s)

  # === VALIDATIONS ===
  validates :name, presence: true, length: { minimum: 3, maximum: 200 }
  validates :title, presence: true, length: { minimum: 5, maximum: 300 }
  validates :report_type, presence: true, inclusion: { in: REPORT_TYPES.keys.map(&:to_s) }
  validates :category, presence: true, inclusion: { in: REPORT_CATEGORIES.keys.map(&:to_s) }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :refresh_interval, numericality: { greater_than: 0 }, allow_nil: true

  # Conditional validations
  validate :query_validation, if: :custom_query?
  validate :data_source_availability, if: :data_sources_present?
  validate :permission_requirements_met

  # === CALLBACKS ===
  before_validation :set_defaults, :enrich_report_metadata
  after_create :initialize_report_structure, :setup_default_schedules
  after_update :propagate_changes_to_schedules, if: :significant_changes?
  after_create :trigger_initial_execution, if: :auto_execute_on_creation?
  before_destroy :archive_report_data, prepend: true

  # === SCOPES ===
  scope :active, -> { where(status: :active) }
  scope :scheduled, -> { where(scheduled: true) }
  scope :public_reports, -> { where(is_public: true) }
  scope :by_category, ->(category) { where(category: category) }

  # Advanced scopes for intelligent report management
  scope :real_time_capable, -> { where(real_time_processing: true) }
  scope :ai_enhanced, -> { where(ai_insights_enabled: true) }
  scope :collaborative, -> { where(collaborative_features: true) }
  scope :critical_priority, -> { where(priority: :critical) }
  scope :overdue_for_refresh, -> {
    where('last_executed_at < ?', refresh_interval.seconds.ago)
  }
  scope :failing_reports, -> {
    joins(:report_executions)
    .where(report_executions: { status: :failed })
    .group('analytics_reports.id')
    .having('COUNT(report_executions.id) >= 3')
  }
  scope :high_usage, -> {
    joins(:access_logs)
    .group('analytics_reports.id')
    .having('COUNT(access_logs.id) >= 100')
  }
  scope :by_organization, ->(org) { where(organization: org) }

  # === CLASS METHODS ===

  # Enhanced report execution with comprehensive error handling
  def execute(params = {})
    execution = report_executions.create!(
      executed_at: Time.current,
      parameters: params,
      status: :running,
      execution_metadata: {
        triggered_by: params[:triggered_by] || 'manual',
        priority: priority,
        estimated_completion: estimate_completion_time
      }
    )

    begin
      # Pre-execution validation
      validate_execution_prerequisites(params)

      # Execute report with enhanced engine
      result = execute_with_enhanced_engine(params)

      # Post-processing and enrichment
      enriched_result = enrich_report_result(result, params)

      # Update execution record
      execution.update!(
        status: :completed,
        result_data: enriched_result,
        result_metadata: extract_result_metadata(enriched_result),
        completed_at: Time.current,
        execution_time: Time.current - execution.executed_at,
        data_quality_score: calculate_data_quality_score(enriched_result)
      )

      # Trigger post-execution actions
      trigger_post_execution_actions(execution, enriched_result)

      enriched_result

    rescue => e
      handle_execution_error(execution, e)
      raise e
    end
  end

  # Create sophisticated executive dashboard
  def self.create_executive_dashboard(user:, title:, **options)
    transaction do
      dashboard = new(
        user: user,
        name: title.parameterize,
        title: title,
        report_type: :executive_dashboard,
        category: :executive,
        status: :active,
        real_time_processing: options[:real_time_updates] || true,
        ai_insights_enabled: options[:ai_insights] || true,
        collaborative_features: options[:collaborative_features] || true,
        refresh_interval: options[:refresh_interval] || 5.minutes,
        priority: :critical,
        data_sources: options[:data_sources] || [:revenue, :customer_metrics, :product_performance],
        configuration: build_dashboard_configuration(options),
        description: options[:description] || "Executive dashboard with real-time business metrics"
      )

      dashboard.save!
      dashboard.setup_dashboard_data_sources
      dashboard
    end
  end

  # Generate AI-powered predictive report
  def self.generate_predictive_report(report_type:, **options)
    # Validate predictive capabilities
    unless REPORT_TYPES[report_type.to_sym][:ai_enhanced]
      raise ArgumentError, "Report type #{report_type} does not support predictive analytics"
    end

    transaction do
      report = new(
        user: options[:user] || User.system_user,
        name: "#{report_type}_predictive_#{Time.current.to_i}",
        title: options[:title] || "Predictive #{report_type.to_s.titleize} Report",
        report_type: report_type,
        category: REPORT_TYPES[report_type.to_sym][:category],
        status: :active,
        ai_insights_enabled: true,
        predictive_analytics: true,
        forecast_horizon: options[:forecast_horizon] || 90.days,
        confidence_interval: options[:confidence_interval] || 0.95,
        configuration: build_predictive_configuration(options)
      )

      report.save!
      report.generate_predictive_content(options)
      report
    end
  end

  # === INSTANCE METHODS ===

  # Advanced caching with intelligent invalidation
  def cached_result(params = {})
    cache_key = generate_cache_key(params)
    cache_ttl = determine_cache_ttl

    Rails.cache.fetch(cache_key, expires_in: cache_ttl, race_condition_ttl: 10.seconds) do
      if should_execute_fresh?(params)
        execute(params)
      else
        retrieve_cached_execution&.result_data
      end
    end
  end

  # Generate multiple export formats
  def generate_exports(formats: [:pdf, :excel], **options)
    exports = {}

    formats.each do |format|
      next unless supports_export_format?(format)

      export_service = ReportExportService.new(
        report: self,
        format: format,
        options: options
      )

      exports[format] = export_service.generate
    end

    exports
  end

  # Share report with intelligent access controls
  def share_with(users:, permissions: :read, **options)
    transaction do
      users.each do |user|
        share = report_shares.create!(
          user: user,
          permission_level: permissions,
          granted_by: options[:granted_by] || Current.user,
          granted_at: Time.current,
          access_restrictions: options[:access_restrictions] || {},
          expires_at: options[:expires_at],
          notification_preferences: options[:notification_preferences] || {}
        )

        # Send notification
        ReportSharingService.notify_share(share, options)
      end
    end
  end

  # Create report snapshot for version control
  def create_snapshot(created_by: nil, notes: nil)
    transaction do
      snapshot = report_versions.create!(
        user: created_by || Current.user,
        snapshot_data: generate_snapshot_data,
        version_number: next_version_number,
        change_notes: notes,
        snapshot_metadata: {
          configuration_hash: configuration_hash,
          data_sources_hash: data_sources_hash,
          execution_stats: execution_statistics
        }
      )

      # Archive current state
      update!(last_snapshot_at: Time.current)

      snapshot
    end
  end

  # === PRIVATE METHODS ===

  private

  # Set default values before validation
  def set_defaults
    self.status ||= :draft
    self.priority ||= :medium
    self.refresh_interval ||= 3600 # 1 hour default
    self.is_public ||= false
    self.real_time_processing ||= false
    self.ai_insights_enabled ||= false
    self.collaborative_features ||= false
    self.scheduled ||= false
    self.configuration ||= {}
    self.report_metadata ||= {}
  end

  # Enrich report metadata with intelligent defaults
  def enrich_report_metadata
    metadata = REPORT_TYPES[report_type.to_sym] || {}

    # Apply metadata defaults
    self.category ||= metadata[:category].to_s
    self.complexity ||= metadata[:complexity].to_s
    self.data_volume ||= metadata[:data_volume].to_s
    self.real_time_processing ||= metadata[:real_time_capable] || false
    self.ai_insights_enabled ||= metadata[:ai_enhanced] || false

    # Set performance expectations
    self.expected_processing_time ||= estimate_processing_time
    self.caching_strategy ||= metadata[:caching_strategy].to_s

    # Set security requirements
    self.required_permissions ||= metadata[:required_permissions] || []
    self.sensitive_data ||= contains_sensitive_data?
  end

  # Execute report with enhanced analytics engine
  def execute_with_enhanced_engine(params)
    case report_type.to_sym
    when :executive_dashboard
      AnalyticsEngine::ExecutiveDashboard.new(self, params).generate
    when :predictive_analytics
      AnalyticsEngine::PredictiveAnalytics.new(self, params).generate
    when :sales_report
      AnalyticsEngine::EnhancedSalesReport.new(self, params).generate
    when :revenue_report
      AnalyticsEngine::EnhancedRevenueReport.new(self, params).generate
    when :customer_report
      AnalyticsEngine::EnhancedCustomerReport.new(self, params).generate
    when :product_report
      AnalyticsEngine::EnhancedProductReport.new(self, params).generate
    when :cohort_report
      AnalyticsEngine::EnhancedCohortReport.new(self, params).generate
    when :market_basket
      AnalyticsEngine::EnhancedMarketBasketReport.new(self, params).generate
    when :traffic_report
      AnalyticsEngine::EnhancedTrafficReport.new(self, params).generate
    when :conversion_report
      AnalyticsEngine::EnhancedConversionReport.new(self, params).generate
    when :custom_query
      AnalyticsEngine::CustomQueryReport.new(self, params).generate
    else
      raise ArgumentError, "Unsupported report type: #{report_type}"
    end
  end

  # Enrich report result with AI insights and context
  def enrich_report_result(result, params)
    enriched_result = result.deep_dup

    # Add AI-powered insights if enabled
    if ai_insights_enabled?
      enriched_result['ai_insights'] = generate_ai_insights(result, params)
    end

    # Add data quality assessment
    enriched_result['data_quality'] = assess_data_quality(result)

    # Add contextual information
    enriched_result['context'] = generate_contextual_metadata(params)

    # Add performance metrics
    enriched_result['performance'] = execution_performance_metrics

    enriched_result
  end

  # Generate AI-powered insights for the report
  def generate_ai_insights(result, params)
    AiInsightsService.generate_insights(
      report: self,
      data: result,
      context: params,
      insight_types: [
        :trend_analysis,
        :anomaly_detection,
        :correlation_analysis,
        :predictive_insights,
        :recommendations
      ]
    )
  end

  # Assess overall data quality of the report
  def assess_data_quality(result)
    DataQualityService.assess_report_quality(
      report: self,
      result: result,
      criteria: [
        :completeness,
        :accuracy,
        :timeliness,
        :consistency,
        :relevance
      ]
    )
  end

  # Generate contextual metadata for the report
  def generate_contextual_metadata(params)
    {
      generated_at: Time.current,
      parameters: params,
      data_freshness: data_freshness_score,
      business_context: extract_business_context,
      user_context: user_context_metadata,
      system_context: system_context_metadata
    }
  end

  # Validate execution prerequisites
  def validate_execution_prerequisites(params)
    # Check data source availability
    unless data_sources_available?
      raise DataSourceError, "Required data sources are not available"
    end

    # Check user permissions
    unless user_has_execution_permissions?
      raise PermissionError, "User lacks execution permissions for this report"
    end

    # Check system resource availability
    unless system_resources_available?
      raise ResourceError, "Insufficient system resources for report execution"
    end

    # Validate parameters
    ParameterValidationService.validate(self, params)
  end

  # Handle execution errors with comprehensive logging
  def handle_execution_error(execution, error)
    execution.update!(
      status: :failed,
      error_message: error.message,
      error_details: {
        error_class: error.class.name,
        backtrace: error.backtrace&.first(10),
        execution_context: execution.execution_metadata,
        system_state: capture_system_state
      },
      completed_at: Time.current,
      execution_time: Time.current - execution.executed_at
    )

    # Trigger error notifications
    ReportErrorNotificationService.notify_error(
      report: self,
      execution: execution,
      error: error,
      notify_users: error_notification_recipients
    )

    # Create error analysis report
    ErrorAnalysisService.analyze_error(
      report: self,
      error: error,
      execution: execution
    )
  end

  # Trigger post-execution actions
  def trigger_post_execution_actions(execution, result)
    # Distribute report if scheduled
    distribute_report_if_scheduled(execution, result)

    # Update usage statistics
    update_usage_statistics(execution)

    # Trigger dependent processes
    trigger_dependent_processes(result)

    # Archive execution for compliance
    archive_execution_for_compliance(execution) if compliance_required?
  end

  # === CACHING & PERFORMANCE ===

  # Generate intelligent cache key
  def generate_cache_key(params)
    params_hash = Digest::SHA256.hexdigest(params.to_json)
    "report:#{id}:#{cache_version}:#{params_hash}"
  end

  # Determine appropriate cache TTL based on report characteristics
  def determine_cache_ttl
    case caching_strategy.to_sym
    when :aggressive then 15.minutes
    when :moderate then 5.minutes
    when :conservative then 1.minute
    else 3.minutes
    end
  end

  # Check if fresh execution is required
  def should_execute_fresh?(params)
    return true if params.present? # Always execute for new parameters
    return true if stale? # Execute if data is stale
    return true if real_time_processing? # Always fresh for real-time reports
    return false # Use cache for static reports
  end

  # === SEARCH & DISCOVERY ===

  # Elasticsearch integration for report discovery
  searchkick mappings: {
    name: { type: :keyword },
    title: { type: :text, analyzer: :standard },
    description: { type: :text, analyzer: :standard },
    report_type: { type: :keyword },
    category: { type: :keyword },
    tags: { type: :keyword },
    user_email: { type: :keyword },
    created_at: { type: :date }
  }

  def search_data
    {
      name: name,
      title: title,
      description: description,
      report_type: report_type,
      category: category,
      status: status,
      priority: priority,
      user_email: user.email,
      organization_id: organization_id,
      tags: tags || [],
      data_sources: data_sources&.map(&:name),
      complexity: complexity,
      real_time_processing: real_time_processing?,
      ai_insights_enabled: ai_insights_enabled?,
      created_at: created_at,
      last_executed_at: last_executed_at,
      usage_count: access_logs.count
    }
  end

  # === PERFORMANCE OPTIMIZATIONS ===

  # Database indexes for optimal performance
  self.primary_key = :id

  # Composite indexes for common query patterns
  index :created_at
  index [:user_id, :created_at]
  index [:organization_id, :created_at]
  index [:report_type, :status]
  index [:category, :status]
  index [:priority, :status]
  index [:last_executed_at, :status]

  # Partial indexes for specific use cases
  index :refresh_interval, where: "scheduled = true"
  index :is_public, where: "is_public = true"
  index :real_time_processing, where: "real_time_processing = true"
  index :ai_insights_enabled, where: "ai_insights_enabled = true"

  # === HELPER METHODS ===

  # Get last successful execution
  def last_execution
    report_executions.where(status: :completed).order(executed_at: :desc).first
  end

  # Check if report data is stale
  def stale?
    return true unless last_execution

    refresh_interval = configuration['refresh_interval'] || 3600
    last_execution.executed_at < refresh_interval.seconds.ago
  end

  # Check if report supports specific export format
  def supports_export_format?(format)
    metadata = REPORT_TYPES[report_type.to_sym]
    return false unless metadata

    metadata[:export_formats]&.include?(format) || false
  end

  # Estimate processing time based on report characteristics
  def estimate_processing_time
    metadata = REPORT_TYPES[report_type.to_sym]
    return 30.seconds unless metadata

    base_time = metadata[:processing_time] || :medium

    case base_time
    when :very_high then 10.minutes
    when :high then 5.minutes
    when :medium then 2.minutes
    when :low then 30.seconds
    else 1.minute
    end
  end

  # Estimate completion time for execution
  def estimate_completion_time
    estimated_time = estimate_processing_time
    Time.current + estimated_time
  end

  # Check if report contains sensitive data
  def contains_sensitive_data?
    sensitive_indicators = [:financial, :customer, :pii, :confidential]
    category.in?(sensitive_indicators.map(&:to_s)) ||
    report_type.in?(['revenue_report', 'customer_report', 'profit_loss_report'])
  end

  # Check if compliance archiving is required
  def compliance_required?
    sensitive_data? || category.in?(['finance', 'executive'])
  end

  # Get error notification recipients
  def error_notification_recipients
    [user] + shared_with_users.admin + User.with_role(:system_administrator)
  end

  # Capture current system state for error reporting
  def capture_system_state
    {
      server_load: system_load,
      memory_usage: memory_usage,
      database_connections: active_db_connections,
      queue_size: background_queue_size,
      timestamp: Time.current
    }
  end

  # Calculate next version number for snapshots
  def next_version_number
    last_version = report_versions.order(version_number: :desc).first
    last_version&.version_number.to_i + 1 || 1
  end

  # Generate configuration hash for change detection
  def configuration_hash
    Digest::SHA256.hexdigest(configuration.to_json)
  end

  # Generate data sources hash for change detection
  def data_sources_hash
    Digest::SHA256.hexdigest(data_sources.map(&:id).sort.to_json)
  end

  # Get execution statistics for performance monitoring
  def execution_statistics
    executions = report_executions.where(status: :completed).last(100)

    {
      average_execution_time: executions.average(:execution_time),
      success_rate: executions.where(status: :completed).count.to_f / executions.count,
      total_executions: executions.count,
      last_24h_executions: executions.where('executed_at > ?', 24.hours.ago).count
    }
  end

  # Build dashboard configuration
  def self.build_dashboard_configuration(options)
    {
      layout: options[:layout] || :executive_grid,
      widgets: options[:widgets] || default_dashboard_widgets,
      refresh_interval: options[:refresh_interval] || 5.minutes,
      real_time_updates: options[:real_time_updates] || true,
      data_sources: options[:data_sources] || [],
      customization: options[:customization] || {},
      theme: options[:theme] || :professional
    }
  end

  # Build predictive configuration
  def self.build_predictive_configuration(options)
    {
      forecast_horizon: options[:forecast_horizon] || 90.days,
      confidence_interval: options[:confidence_interval] || 0.95,
      include_seasonality: options[:include_seasonality] || true,
      include_external_factors: options[:include_external_factors] || true,
      include_recommendations: options[:include_recommendations] || true,
      model_types: options[:model_types] || [:arima, :prophet, :lstm],
      retrain_frequency: options[:retrain_frequency] || :weekly
    }
  end

  # Default dashboard widgets
  def self.default_dashboard_widgets
    [
      { type: :kpi_summary, position: :top, size: :large },
      { type: :revenue_chart, position: :left, size: :medium },
      { type: :customer_metrics, position: :center, size: :medium },
      { type: :product_performance, position: :right, size: :medium },
      { type: :alerts_summary, position: :bottom, size: :small }
    ]
  end
end
