# =============================================================================
# AccessibilityAudit Model - Refactored Enterprise WCAG Compliance Engine
# =============================================================================
#
# REFACTORED ARCHITECTURE:
# - Clean Model focused solely on data persistence and relationships
# - Business logic extracted to sophisticated service layer
# - Event sourcing for comprehensive audit trails
# - CQRS pattern for optimized read/write operations
# - Advanced validation with contextual business rules
# - Performance monitoring and distributed tracing integration
#
# DESIGN PRINCIPLES:
# - Single Responsibility: Model handles only data persistence
# - Open/Closed: Extended via composition with service objects
# - Liskov Substitution: Clean polymorphic relationships
# - Interface Segregation: Focused method contracts
# - Dependency Inversion: Depends on abstractions, not concretions
#
# SERVICE INTEGRATION:
# - AuditExecutionService: Sophisticated audit orchestration
# - ComplianceScoringService: Advanced scoring algorithms
# - AuditResultProcessor: Trend analysis and insights
# - AuditReportPresenter: Multi-format report generation
# - Event sourcing and CQRS for state management
# =============================================================================

class AccessibilityAudit < ApplicationRecord
  include AccessibilityAudit::Concerns::EventSourcing
  include AccessibilityAudit::Concerns::AuditTrail
  include AccessibilityAudit::Concerns::PerformanceTracking

  # ============================================================================
  # ASSOCIATIONS & CORE RELATIONSHIPS
  # ============================================================================

  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  has_many :audit_events, class_name: 'AccessibilityAudit::AuditEvent', dependent: :destroy
  has_many :audit_snapshots, class_name: 'AccessibilityAudit::AuditSnapshot', dependent: :destroy

  # Legacy associations for backward compatibility
  has_many :audit_issues, dependent: :destroy
  has_many :audit_recommendations, dependent: :destroy
  has_many :audit_executions, dependent: :all

  # ============================================================================
  # ADVANCED VALIDATIONS WITH CONTEXT
  # ============================================================================

  validates :page_url, presence: true, url: true, length: { maximum: 2048 }
  validates :audit_type, presence: true
  validates :wcag_version, presence: true, inclusion: { in: %w[WCAG2.0 WCAG2.1 WCAG2.2] }

  # Enhanced validation with contextual business rules
  validates :audit_scope, inclusion: { in: %w[full_page single_element component custom] }
  validates :sample_size, numericality: { greater_than: 0, less_than_or_equal_to: 10000 }, allow_nil: true

  # Sophisticated custom validations
  validate :validate_audit_context, if: :audit_context_present?
  validate :validate_resource_availability, if: :resource_intensive_audit?
  validate :validate_user_permissions, if: :user_present?

  # Enhanced enum definitions with comprehensive metadata
  enum audit_type: {
    automated: 0,
    manual: 1,
    user_testing: 2,
    compliance_check: 3,
    security_audit: 4,
    performance_audit: 5,
    regression_test: 6
  }, _prefix: true

  enum wcag_level: {
    level_a: 0,
    level_aa: 1,
    level_aaa: 2
  }, _prefix: true

  enum status: {
    pending: 0,
    running: 1,
    completed: 2,
    failed: 3,
    cancelled: 4,
    partially_completed: 5
  }, _default: :pending

  enum audit_scope: {
    full_page: 0,
    single_element: 1,
    component: 2,
    custom: 3
  }

  # ============================================================================
  # ADVANCED QUERY INTERFACES (CQRS)
  # ============================================================================

  # Execute sophisticated audit using service layer orchestration
  def execute_audit(options = {})
    audit_service = AccessibilityAudit::AuditExecutionService.new(self, options)

    begin
      audit_service.execute_automated_audit
    rescue => e
      handle_audit_execution_failure(e)
      raise e
    end
  end

  # Execute batch audit with advanced load balancing
  def execute_batch_audit(urls, options = {})
    audit_service = AccessibilityAudit::AuditExecutionService.new(self, options)

    begin
      audit_service.execute_batch_audit(urls)
    rescue => e
      handle_batch_execution_failure(e)
      raise e
    end
  end

  # Cancel audit with proper cleanup and event generation
  def cancel_audit(reason = nil, cancelled_by: nil)
    command_service = AccessibilityAudit::AuditCommandService.new

    metadata = {
      user_id: cancelled_by&.id || user_id,
      reason: reason,
      timestamp: Time.current
    }

    begin
      command_service.cancel_audit(id, reason, metadata)
    rescue => e
      handle_cancellation_failure(e)
      raise e
    end
  end

  # Calculate comprehensive compliance score using advanced algorithms
  def calculate_compliance_score
    scoring_service = AccessibilityAudit::ComplianceScoringService.new(self, results || {})

    begin
      scoring_service.calculate_comprehensive_score
    rescue => e
      handle_scoring_failure(e)
      { final_score: 0.0, error: e.message }
    end
  end

  # Process audit results with trend analysis and insights
  def process_results
    result_processor = AccessibilityAudit::AuditResultProcessor.new(self, results || {})

    begin
      result_processor.process_comprehensive_results
    rescue => e
      handle_result_processing_failure(e)
      { error: e.message, processed_at: Time.current }
    end
  end

  # Generate sophisticated reports using presenter layer
  def generate_report(format = :json, audience = :technical, options = {})
    report_presenter = AccessibilityAudit::AuditReportPresenter.new(self, results || {})

    begin
      report_presenter.generate_report(format, audience, options)
    rescue => e
      handle_report_generation_failure(e)
      { error: e.message, format: format, audience: audience }
    end
  end

  # Get compliance status with sophisticated classification
  def compliance_status
    return 'unknown' unless score

    case score
    when 90..100 then 'excellent'
    when 75..89 then 'good'
    when 60..74 then 'fair'
    when 40..59 then 'poor'
    else 'critical'
    end
  end

  # Get actionable recommendations with priority scoring
  def recommendations
    return [] unless results

    result_processor = AccessibilityAudit::AuditResultProcessor.new(self, results)
    processed_results = result_processor.process_comprehensive_results

    processed_results[:recommendations] || []
  end

  # Generate audit summary for quick overview
  def audit_summary
    {
      audit_id: id,
      page_url: page_url,
      status: status,
      score: score,
      compliance_status: compliance_status,
      created_at: created_at,
      completed_at: completed_at,
      duration: calculate_duration,
      issue_count: issue_count,
      recommendation_count: recommendation_count
    }
  end

  # ============================================================================
  # EVENT SOURCING INTEGRATION
  # ============================================================================

  # Apply event to current state (for event sourcing)
  def apply_event(event)
    event.apply_to(self)

    # Update audit trail
    record_audit_event(event)

    # Create snapshot periodically for performance
    create_snapshot_if_needed(event)

    save!
  end

  # Rebuild state from event history (for debugging and recovery)
  def rebuild_from_events
    snapshot = latest_snapshot

    if snapshot.present?
      restore_from_snapshot(snapshot)
    else
      rebuild_from_event_history
    end
  end

  # Get audit history for compliance and debugging
  def audit_history
    {
      events: audit_events.order(timestamp: :asc).map(&:to_h),
      snapshots: audit_snapshots.order(created_at: :desc).limit(10).map(&:to_h),
      timeline: build_audit_timeline,
      compliance_trail: build_compliance_trail
    }
  end

  # ============================================================================
  # ADVANCED QUERY METHODS
  # ============================================================================

  # Find audits by user with sophisticated filtering
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  # Find audits by URL pattern
  scope :by_url_pattern, ->(pattern) { where('page_url LIKE ?', "%#{pattern}%") }

  # Find audits by date range
  scope :in_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  # Find audits by compliance status
  scope :by_compliance_status, ->(status) do
    score_ranges = {
      'excellent' => (90..100),
      'good' => (75..89),
      'fair' => (60..74),
      'poor' => (40..59),
      'critical' => (0..39)
    }

    score_range = score_ranges[status]
    return none unless score_range

    where(score: score_range)
  end

  # Find audits requiring attention (low scores, failed audits)
  scope :requiring_attention, -> do
    where(status: [:failed, :partially_completed])
    .or(where(score: 0..59))
    .order(score: :asc, created_at: :desc)
  end

  # Find recent audits for trend analysis
  scope :recent_for_trends, ->(days = 30) do
    where('created_at >= ?', days.days.ago)
    .order(created_at: :desc)
  end

  # ============================================================================
  # PERFORMANCE MONITORING INTEGRATION
  # ============================================================================

  # Monitor audit performance metrics
  def performance_metrics
    performance_tracker = AccessibilityAudit::PerformanceTracker.new(self)

    {
      execution_time: performance_tracker.execution_time,
      memory_usage: performance_tracker.memory_usage,
      cpu_utilization: performance_tracker.cpu_utilization,
      database_queries: performance_tracker.database_queries,
      external_api_calls: performance_tracker.external_api_calls,
      caching_effectiveness: performance_tracker.caching_effectiveness
    }
  end

  # Get performance insights and recommendations
  def performance_insights
    performance_analyzer = AccessibilityAudit::PerformanceAnalyzer.new(self)

    performance_analyzer.generate_insights
  end

  private

  # ============================================================================
  # VALIDATION METHODS
  # ============================================================================

  # Validate audit context and business rules
  def validate_audit_context
    # Validate WCAG version compatibility with audit type
    if security_audit? && !['WCAG2.1', 'WCAG2.2'].include?(wcag_version)
      errors.add(:wcag_version, 'must be WCAG 2.1 or 2.2 for security audits')
    end

    # Validate sample size for comprehensive audits
    if full_page? && sample_size.blank?
      errors.add(:sample_size, 'is required for full page audits')
    end

    # Validate URL accessibility for automated audits
    if automated? && !url_accessible?
      errors.add(:page_url, 'must be accessible for automated audits')
    end
  end

  # Validate resource availability for intensive audits
  def validate_resource_availability
    resource_validator = AccessibilityAudit::SystemResourceValidator.new

    begin
      resource_validator.validate!
    rescue => e
      errors.add(:base, "Insufficient system resources: #{e.message}")
    end
  end

  # Validate user permissions for audit execution
  def validate_user_permissions
    return unless user

    permission_validator = AccessibilityAudit::UserPermissionValidator.new(user)

    unless permission_validator.can_execute_audit?(self)
      errors.add(:user, 'does not have permission to execute this audit')
    end
  end

  # Check if audit context is present for validation
  def audit_context_present?
    audit_type.present? && wcag_version.present?
  end

  # Check if audit is resource intensive
  def resource_intensive_audit?
    full_page? || security_audit? || performance_audit?
  end

  # Check if user is present for validation
  def user_present?
    user.present?
  end

  # Check if URL is accessible
  def url_accessible?
    accessibility_checker = AccessibilityAudit::UrlAccessibilityChecker.new(
      url: page_url,
      timeout: 10,
      retries: 2
    )

    accessibility_checker.accessible?
  rescue
    false
  end

  # ============================================================================
  # ERROR HANDLING METHODS
  # ============================================================================

  # Handle audit execution failure
  def handle_audit_execution_failure(error)
    error_logger = AccessibilityAudit::ErrorLogger.new

    error_logger.log_error(
      error_type: :audit_execution_failure,
      audit_id: id,
      error: error.message,
      context: audit_context
    )

    update!(
      status: :failed,
      error_message: error.message,
      failed_at: Time.current
    )
  end

  # Handle batch execution failure
  def handle_batch_execution_failure(error)
    error_logger = AccessibilityAudit::ErrorLogger.new

    error_logger.log_error(
      error_type: :batch_execution_failure,
      audit_id: id,
      error: error.message,
      context: { audit_type: :batch, page_url: page_url }
    )
  end

  # Handle cancellation failure
  def handle_cancellation_failure(error)
    error_logger = AccessibilityAudit::ErrorLogger.new

    error_logger.log_error(
      error_type: :cancellation_failure,
      audit_id: id,
      error: error.message,
      context: audit_context
    )
  end

  # Handle scoring failure
  def handle_scoring_failure(error)
    error_logger = AccessibilityAudit::ErrorLogger.new

    error_logger.log_error(
      error_type: :scoring_failure,
      audit_id: id,
      error: error.message,
      context: audit_context
    )
  end

  # Handle result processing failure
  def handle_result_processing_failure(error)
    error_logger = AccessibilityAudit::ErrorLogger.new

    error_logger.log_error(
      error_type: :result_processing_failure,
      audit_id: id,
      error: error.message,
      context: audit_context
    )
  end

  # Handle report generation failure
  def handle_report_generation_failure(error)
    error_logger = AccessibilityAudit::ErrorLogger.new

    error_logger.log_error(
      error_type: :report_generation_failure,
      audit_id: id,
      error: error.message,
      context: audit_context
    )
  end

  # ============================================================================
  # EVENT SOURCING METHODS
  # ============================================================================

  # Record audit event for trail
  def record_audit_event(event)
    audit_events.create!(
      event_id: event.event_id,
      event_type: event.event_type,
      event_data: event.event_data,
      metadata: event.metadata,
      timestamp: event.timestamp,
      user_id: user_id
    )
  end

  # Create snapshot if needed for performance
  def create_snapshot_if_needed(event)
    # Create snapshot every 10 events or for significant state changes
    if audit_events.count % 10 == 0 || significant_state_change?(event)
      create_snapshot!
    end
  end

  # Create audit snapshot for performance
  def create_snapshot!
    snapshot_data = {
      status: status,
      score: score,
      results: results,
      issue_count: issue_count,
      recommendation_count: recommendation_count,
      snapshot_metadata: {
        event_count: audit_events.count,
        created_at: Time.current
      }
    }

    audit_snapshots.create!(snapshot_data: snapshot_data)
  end

  # Get latest snapshot
  def latest_snapshot
    audit_snapshots.order(created_at: :desc).first
  end

  # Restore from snapshot
  def restore_from_snapshot(snapshot)
    snapshot_data = snapshot.snapshot_data

    update!(
      status: snapshot_data['status'],
      score: snapshot_data['score'],
      results: snapshot_data['results']
    )
  end

  # Rebuild from event history
  def rebuild_from_event_history
    # Apply events in order to rebuild state
    audit_events.order(timestamp: :asc).each do |event_record|
      event = AccessibilityAudit::AuditEvent.from_h(event_record.to_h)
      apply_event(event)
    end
  end

  # Check if event represents significant state change
  def significant_state_change?(event)
    significant_events = [
      'audit_started',
      'audit_completed',
      'audit_failed',
      'audit_cancelled'
    ]

    significant_events.include?(event.event_type)
  end

  # ============================================================================
  # UTILITY METHODS
  # ============================================================================

  # Calculate audit duration
  def calculate_duration
    return nil unless started_at && completed_at

    completed_at - started_at
  end

  # Get issue count from results
  def issue_count
    results&.dig('issues')&.count || 0
  end

  # Get recommendation count from results
  def recommendation_count
    results&.dig('recommendations')&.count || 0
  end

  # Get audit context for error handling
  def audit_context
    {
      audit_id: id,
      user_id: user_id,
      page_url: page_url,
      audit_type: audit_type,
      wcag_level: wcag_level,
      status: status
    }
  end

  # ============================================================================
  # LEGACY COMPATIBILITY METHODS
  # ============================================================================

  # Legacy method for backward compatibility
  def self.run_automated_audit(page_url, user: nil, options: {})
    audit = create!(
      page_url: page_url,
      user: user,
      audit_type: :automated,
      wcag_version: options.fetch(:wcag_version, 'WCAG2.1'),
      status: :running,
      started_at: Time.current
    )

    audit.execute_audit(options)
    audit
  rescue => e
    audit.update!(status: :failed, error_message: e.message) if audit.persisted?
    raise e
  end

  # Legacy method for backward compatibility
  def self.run_batch_audit(urls, user: nil, options: {})
    audit_service = AccessibilityAudit::AuditExecutionService.new(
      AccessibilityAudit.new(user: user),
      options
    )

    audit_service.execute_batch_audit(urls)
  end

  # Legacy compatibility methods removed to eliminate duplication; main methods are more comprehensive

  # Build audit timeline for visualization
  def build_audit_timeline
    events = audit_events.order(timestamp: :asc).map do |event|
      {
        timestamp: event.timestamp,
        event_type: event.event_type,
        description: event_description(event.event_type),
        metadata: event.metadata
      }
    end

    events.group_by { |event| event[:timestamp].to_date }
  end

  # Build compliance trail for audit evidence
  def build_compliance_trail
    {
      compliance_history: compliance_history_data,
      standard_mappings: standard_mappings_data,
      evidence_links: evidence_links_data,
      certification_path: certification_path_data
    }
  end

  # Get event description for timeline
  def event_description(event_type)
    descriptions = {
      'audit_started' => 'Audit execution started',
      'audit_completed' => 'Audit completed successfully',
      'audit_failed' => 'Audit failed',
      'audit_cancelled' => 'Audit cancelled',
      'compliance_calculated' => 'Compliance score calculated',
      'report_generated' => 'Report generated'
    }

    descriptions[event_type] || 'Audit event occurred'
  end

  # Placeholder methods for sophisticated data extraction
  def compliance_history_data; []; end
  def standard_mappings_data; {}; end
  def evidence_links_data; []; end
  def certification_path_data; {}; end
end