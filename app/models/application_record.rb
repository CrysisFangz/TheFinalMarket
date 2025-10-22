# frozen_string_literal: true

# Enterprise-grade ActiveRecord foundation providing comprehensive
# security, performance, monitoring, and compliance capabilities
# to all application models
#
# @author Kilo Code Autonomous Agent
# @version 2.0.0
# @since 2025-10-19
#
# @example
#   class User < ApplicationRecord
#     # Inherits all enterprise features automatically
#     include EnterpriseSecurityFeatures
#     include PerformanceOptimizations
#     include AuditTrailCapabilities
#   end
#
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # === CONSTANTS ===

  # Data classification levels for compliance
  DATA_CLASSIFICATIONS = {
    public_data: { level: 0, retention: nil, encryption_required: false },
    internal_use: { level: 1, retention: 3.years, encryption_required: false },
    sensitive_personal: { level: 2, retention: 5.years, encryption_required: true },
    sensitive_financial: { level: 3, retention: 7.years, encryption_required: true },
    sensitive_legal: { level: 3, retention: 10.years, encryption_required: true },
    restricted_security: { level: 4, retention: 10.years, encryption_required: true },
    confidential_commercial: { level: 4, retention: 7.years, encryption_required: true }
  }.freeze

  # Performance optimization thresholds
  PERFORMANCE_THRESHOLDS = {
    slow_query: { threshold_ms: 1000, action: :log_warning },
    very_slow_query: { threshold_ms: 5000, action: :log_error },
    memory_intensive: { threshold_mb: 100, action: :optimize_query },
    high_frequency: { threshold_per_minute: 1000, action: :cache_result }
  }.freeze

  # Audit event types
  AUDIT_EVENTS = {
    create: { severity: :low, retention: 3.years, compliance_flags: [] },
    update: { severity: :low, retention: 3.years, compliance_flags: [] },
    destroy: { severity: :medium, retention: 7.years, compliance_flags: [:gdpr] },
    bulk_operation: { severity: :high, retention: 5.years, compliance_flags: [:audit_required] },
    security_event: { severity: :critical, retention: 10.years, compliance_flags: [:sox, :pci_dss] }
  }.freeze

  # === ASSOCIATIONS ===

  # Multi-tenancy support (optional organization context)
  belongs_to :organization, optional: true if column_names.include?('organization_id')

  # Audit trail associations
  has_many :audit_logs, class_name: 'ModelAuditLog', dependent: :destroy if defined?(ModelAuditLog)
  has_many :change_histories, class_name: 'ModelChangeHistory', dependent: :destroy if defined?(ModelChangeHistory)

  # Performance monitoring associations
  has_many :performance_metrics, class_name: 'ModelPerformanceMetric', dependent: :destroy if defined?(ModelPerformanceMetric)
  has_many :query_executions, class_name: 'QueryExecutionLog', dependent: :destroy if defined?(QueryExecutionLog)

  # Security associations
  has_many :access_attempts, class_name: 'ModelAccessAttempt', dependent: :destroy if defined?(ModelAccessAttempt)
  has_many :security_events, class_name: 'ModelSecurityEvent', dependent: :destroy if defined?(ModelSecurityEvent)

  # === ENCRYPTION & SECURITY ===

  # Global encryption configuration for sensitive fields
  encrypts :encrypted_metadata, deterministic: true if column_names.include?('encrypted_metadata')
  encrypts :security_context, deterministic: true if column_names.include?('security_context')
  blind_index :encrypted_metadata, :security_context

  # === VALIDATIONS ===

  # Global validations applicable to all models
  validates :data_classification, inclusion: {
    in: DATA_CLASSIFICATIONS.keys.map(&:to_s)
  }, allow_nil: true if column_names.include?('data_classification')

  validates :compliance_flags, array_inclusion: {
    in: [:gdpr, :ccpa, :sox, :pci_dss, :iso27001, :audit_required]
  }, allow_nil: true if column_names.include?('compliance_flags')

  # === CALLBACKS ===

  # Global callbacks for enterprise features
  before_validation :set_global_defaults, :sanitize_input_data, :validate_security_context
  before_create :initialize_enterprise_features, :setup_audit_trail
  before_update :validate_change_permissions, :enrich_update_context
  before_destroy :validate_deletion_permissions, :create_deletion_audit_trail, prepend: true

  after_create :trigger_post_creation_hooks, :update_global_metrics
  after_update :trigger_post_update_hooks, :propagate_changes
  after_destroy :trigger_post_deletion_hooks, :cleanup_associated_data

  after_commit :broadcast_changes, :update_search_indexes
  after_rollback :handle_rollback_events

  # === SCOPES ===

  # Global scopes for common filtering patterns
  scope :recent, ->(timeframe = 24.hours) { where('created_at > ?', timeframe.ago) }
  scope :active, -> { where(active: true) if column_names.include?('active') }
  scope :for_organization, ->(org) { where(organization: org) if column_names.include?('organization_id') }
  scope :sensitive_data, -> { where(data_classification: [:sensitive_personal, :sensitive_financial, :sensitive_legal, :restricted_security]) if column_names.include?('data_classification') }
  scope :compliance_required, -> { where('compliance_flags IS NOT NULL AND array_length(compliance_flags, 1) > 0') if column_names.include?('compliance_flags') }
  scope :high_security, -> { where(security_level: [:restricted, :confidential]) if column_names.include?('security_level') }

  # Performance-optimized scopes
  scope :cache_friendly, -> { includes(*default_includes) }
  scope :performance_optimized, -> { includes(*performance_includes) }

  # === CLASS METHODS ===

  # Enhanced find_or_create with enterprise features
  def self.find_or_create_with_enterprise_features(attributes, &block)
    transaction do
      # Check for existing record with enhanced logic
      existing_record = find_existing_with_context(attributes)

      if existing_record
        # Update existing record if needed
        update_existing_enterprise_record(existing_record, attributes)
        existing_record
      else
        # Create new record with enterprise initialization
        create_with_enterprise_features(attributes, &block)
      end
    end
  end

  # Bulk operations with enhanced performance and monitoring
  def self.bulk_insert_with_enterprise_features(records_data, **options)
    transaction do
      batch_size = options[:batch_size] || 1000
      total_records = records_data.count

      # Pre-process records for enterprise features
      processed_records = preprocess_bulk_records(records_data, options)

      # Insert in optimized batches
      inserted_records = []

      processed_records.each_slice(batch_size) do |batch|
        batch_result = insert_batch_with_monitoring(batch, options)
        inserted_records.concat(batch_result)

        # Progress monitoring
        progress = (inserted_records.count.to_f / total_records * 100).round(2)
        monitor_bulk_operation_progress(progress, options)
      end

      # Post-processing for inserted records
      postprocess_bulk_insert(inserted_records, options)

      inserted_records
    end
  end

  # Advanced search with enterprise security and performance
  def self.enterprise_search(query, **options)
    # Apply security filters based on current user context
    secured_query = apply_security_filters(query, options)

    # Apply performance optimizations
    optimized_query = apply_performance_optimizations(secured_query, options)

    # Execute search with monitoring
    execute_search_with_monitoring(optimized_query, options)
  end

  # Generate comprehensive analytics for the model
  def self.generate_model_analytics(**options)
    analytics_service = ModelAnalyticsService.new(self)

    {
      record_count: count,
      growth_rate: analytics_service.calculate_growth_rate(options[:timeframe]),
      data_quality: analytics_service.assess_data_quality,
      performance_metrics: analytics_service.performance_metrics,
      security_metrics: analytics_service.security_metrics,
      compliance_status: analytics_service.compliance_status,
      usage_patterns: analytics_service.usage_patterns
    }
  end

  # === INSTANCE METHODS ===

  # Enhanced save with enterprise features
  def save_with_enterprise_features(**options)
    transaction do
      # Pre-save validation and enrichment
      validate_enterprise_constraints(options)

      # Execute save with monitoring
      save_result = save_with_monitoring(**options)

      # Post-save processing
      if save_result
        process_post_save_enterprise_features(options)
      end

      save_result
    end
  end

  # Generate comprehensive audit trail
  def generate_audit_trail(**options)
    audit_service = AuditTrailService.new(self)

    audit_service.generate_comprehensive_trail(
      include_changes: options[:include_changes] || true,
      include_context: options[:include_context] || true,
      include_security: options[:include_security] || true,
      timeframe: options[:timeframe] || 30.days
    )
  end

  # Check data retention compliance
  def check_retention_compliance
    return unless data_classification.present?

    classification = DATA_CLASSIFICATIONS[data_classification.to_sym]
    return unless classification

    retention_period = classification[:retention]
    return unless retention_period && created_at

    if Time.current > created_at + retention_period
      handle_retention_expiry
    end
  end

  # Encrypt sensitive fields before storage
  def encrypt_sensitive_fields
    sensitive_fields = self.class.sensitive_fields || []

    sensitive_fields.each do |field|
      next unless attribute_present?(field)

      encrypted_value = EncryptionService.encrypt_sensitive_data(
        send(field),
        classification: data_classification,
        field_name: field
      )

      send("#{field}=", encrypted_value)
    end
  end

  # Decrypt sensitive fields for access
  def decrypt_sensitive_fields
    sensitive_fields = self.class.sensitive_fields || []

    sensitive_fields.each do |field|
      next unless attribute_present?(field)

      decrypted_value = EncryptionService.decrypt_sensitive_data(
        send(field),
        classification: data_classification,
        field_name: field
      )

      send("#{field}=", decrypted_value)
    end
  end

  # === PRIVATE METHODS ===

  private

  # Set global default values for enterprise features
  def set_global_defaults
    # Set default data classification
    self.data_classification ||= :internal_use if column_names.include?('data_classification')

    # Set default compliance flags
    self.compliance_flags ||= [] if column_names.include?('compliance_flags')

    # Set default security level
    self.security_level ||= :standard if column_names.include?('security_level')

    # Set default active status
    self.active ||= true if column_names.include?('active')

    # Set default organization context
    if column_names.include?('organization_id') && !organization_id && Current.organization
      self.organization = Current.organization
    end
  end

  # Sanitize input data for security
  def sanitize_input_data
    # Sanitize string fields
    string_fields = attribute_names.select do |attr|
      column_for_attribute(attr)&.type == :string
    end

    string_fields.each do |field|
      next unless attribute_present?(field)

      sanitized_value = InputSanitizationService.sanitize(
        send(field),
        field_type: :string,
        max_length: column_for_attribute(field)&.limit,
        allow_html: field_allows_html?(field)
      )

      send("#{field}=", sanitized_value)
    end

    # Validate data integrity
    validate_data_integrity
  end

  # Validate security context for the operation
  def validate_security_context
    # Check if current user has permission for this operation
    unless current_user_has_permission?
      errors.add(:base, "Insufficient permissions for this operation")
      throw(:abort)
    end

    # Validate organization context
    if organization_required? && !organization_id
      errors.add(:organization, "is required for this operation")
      throw(:abort)
    end

    # Check data classification permissions
    if sensitive_data_operation? && !current_user_can_access_sensitive_data?
      errors.add(:base, "Operation not permitted for this data classification")
      throw(:abort)
    end
  end

  # Initialize enterprise features for new records
  def initialize_enterprise_features
    # Set creation metadata
    self.created_by ||= Current.user&.id
    self.created_ip ||= Current.ip_address
    self.created_user_agent ||= Current.user_agent

    # Initialize audit trail
    self.audit_trail_enabled ||= true
    self.change_tracking_enabled ||= true

    # Set initial data quality score
    self.data_quality_score ||= calculate_initial_data_quality_score

    # Initialize performance tracking
    self.performance_monitoring_enabled ||= true

    # Set encryption requirements
    self.encryption_required ||= requires_encryption?
  end

  # Setup comprehensive audit trail
  def setup_audit_trail
    return unless audit_trail_enabled?

    # Create initial audit log entry
    create_audit_log_entry(
      event: :create,
      changes: attributes.compact,
      user: Current.user,
      context: build_audit_context,
      metadata: build_audit_metadata
    )
  end

  # Validate change permissions before update
  def validate_change_permissions
    return unless change_tracking_enabled?

    # Check if user can modify this record
    unless current_user_can_modify_record?
      errors.add(:base, "Insufficient permissions to modify this record")
      throw(:abort)
    end

    # Validate field-level permissions
    validate_field_level_permissions

    # Check for sensitive data changes
    if sensitive_data_changes?
      validate_sensitive_data_change_permissions
    end
  end

  # Enrich update context with additional metadata
  def enrich_update_context
    return unless change_tracking_enabled?

    # Capture update metadata
    self.updated_by = Current.user&.id
    self.updated_ip = Current.ip_address
    self.updated_user_agent = Current.user_agent
    self.last_updated_at = Time.current

    # Calculate change significance
    self.change_significance_score = calculate_change_significance_score

    # Update data quality score
    self.data_quality_score = recalculate_data_quality_score
  end

  # Validate deletion permissions
  def validate_deletion_permissions
    return unless persisted?

    # Check if user can delete this record
    unless current_user_can_delete_record?
      errors.add(:base, "Insufficient permissions to delete this record")
      throw(:abort)
    end

    # Check for dependent records that would be affected
    if has_critical_dependencies?
      errors.add(:base, "Cannot delete record with critical dependencies")
      throw(:abort)
    end

    # Validate retention policy compliance
    unless deletion_compliant_with_retention_policy?
      errors.add(:base, "Deletion violates data retention policy")
      throw(:abort)
    end
  end

  # Create comprehensive deletion audit trail
  def create_deletion_audit_trail
    return unless audit_trail_enabled?

    # Create deletion audit log
    create_audit_log_entry(
      event: :destroy,
      changes: { deleted_attributes: attributes.compact },
      user: Current.user,
      context: {
        deletion_reason: deletion_reason,
        cascade_effects: cascade_deletion_effects,
        compliance_check: deletion_compliance_check
      },
      metadata: build_deletion_metadata
    )
  end

  # === ENTERPRISE FEATURE METHODS ===

  # Trigger post-creation enterprise hooks
  def trigger_post_creation_hooks
    # Index for search if applicable
    update_search_indexes if search_enabled?

    # Trigger notifications if configured
    trigger_creation_notifications

    # Initialize performance monitoring
    initialize_performance_monitoring

    # Setup compliance monitoring
    setup_compliance_monitoring if compliance_required?
  end

  # Trigger post-update enterprise hooks
  def trigger_post_update_hooks
    # Update search indexes
    update_search_indexes if search_enabled?

    # Trigger change notifications
    trigger_update_notifications

    # Update dependent caches
    update_dependent_caches

    # Propagate changes to related systems
    propagate_changes_to_external_systems

    # Update compliance status
    update_compliance_status if compliance_required?
  end

  # Trigger post-deletion enterprise hooks
  def trigger_post_deletion_hooks
    # Remove from search indexes
    remove_from_search_indexes if search_enabled?

    # Trigger deletion notifications
    trigger_deletion_notifications

    # Cleanup external references
    cleanup_external_references

    # Archive related data
    archive_related_data if archiving_required?

    # Update compliance records
    update_compliance_records_for_deletion
  end

  # Broadcast changes for real-time updates
  def broadcast_changes
    return unless real_time_updates_enabled?

    # Broadcast via ActionCable
    broadcast_via_action_cable

    # Broadcast via WebSockets
    broadcast_via_websockets

    # Trigger external webhook notifications
    trigger_webhook_notifications
  end

  # Update search indexes for full-text search
  def update_search_indexes
    return unless search_enabled?

    # Update Elasticsearch indexes
    update_elasticsearch_indexes

    # Update other search service indexes
    update_external_search_indexes
  end

  # Handle rollback events for error recovery
  def handle_rollback_events
    # Log rollback event
    log_rollback_event

    # Trigger rollback notifications
    trigger_rollback_notifications

    # Cleanup partial data
    cleanup_partial_data if transaction_rolled_back?
  end

  # === PERFORMANCE OPTIMIZATION ===

  # Save with comprehensive performance monitoring
  def save_with_monitoring(**options)
    start_time = Time.current

    # Execute save with monitoring
    result = save(**options)

    # Record performance metrics
    execution_time = Time.current - start_time
    record_performance_metrics(execution_time, options)

    # Trigger performance alerts if needed
    trigger_performance_alerts(execution_time)

    result
  end

  # Record comprehensive performance metrics
  def record_performance_metrics(execution_time, options)
    return unless performance_monitoring_enabled?

    performance_metrics.create!(
      operation: options[:context] || 'save',
      execution_time: execution_time,
      memory_usage: current_memory_usage,
      database_queries: recorded_query_count,
      cache_hits: recorded_cache_hits,
      error_occurred: options[:error_occurred] || false,
      context: options[:performance_context] || {},
      metadata: build_performance_metadata
    )
  end

  # === SECURITY METHODS ===

  # Check if current user has operation permissions
  def current_user_has_permission?
    return true unless Current.user

    # Check model-level permissions
    return false unless Current.user.can_access_model?(self.class.name)

    # Check record-level permissions
    return false unless Current.user.can_access_record?(self)

    # Check organization-level permissions
    if organization_id && Current.user.organization_id != organization_id
      return false unless Current.user.has_cross_organization_access?
    end

    true
  end

  # Check if current user can access sensitive data
  def current_user_can_access_sensitive_data?
    return false unless Current.user

    sensitive_classifications = [:sensitive_personal, :sensitive_financial,
                               :sensitive_legal, :restricted_security]

    return false if sensitive_classifications.include?(data_classification&.to_sym) &&
                   !Current.user.has_sensitive_data_access?

    true
  end

  # Check if current user can modify this record
  def current_user_can_modify_record?
    return false unless Current.user
    return false unless current_user_has_permission?

    # Check if record is locked for editing
    return false if locked_for_editing?

    # Check if user is the owner or has admin privileges
    return true if Current.user.admin? || owned_by_current_user?

    # Check specific modification permissions
    Current.user.can_modify_record?(self)
  end

  # Check if current user can delete this record
  def current_user_can_delete_record?
    return false unless Current.user
    return false unless current_user_has_permission?

    # Check if record has deletion restrictions
    return false if deletion_restricted?

    # Check if user has deletion permissions
    Current.user.can_delete_record?(self)
  end

  # === AUDIT TRAIL METHODS ===

  # Create comprehensive audit log entry
  def create_audit_log_entry(event:, changes: {}, user: nil, context: {}, metadata: {})
    return unless audit_trail_enabled?

    audit_logs.create!(
      event: event,
      changes: changes,
      user: user || Current.user,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent,
      session_id: Current.session_id,
      context: context,
      metadata: metadata,
      organization: organization || Current.organization,
      data_classification: data_classification,
      compliance_flags: compliance_flags,
      risk_score: calculate_audit_risk_score(event, changes),
      created_at: Time.current
    )
  end

  # Build comprehensive audit context
  def build_audit_context
    {
      model_name: self.class.name,
      record_id: id,
      operation_type: new_record? ? :create : :update,
      timestamp: Time.current,
      system_context: extract_system_context,
      business_context: extract_business_context,
      security_context: extract_security_context
    }
  end

  # Build audit metadata for compliance
  def build_audit_metadata
    {
      data_classification: data_classification,
      compliance_flags: compliance_flags,
      retention_period: get_retention_period,
      encryption_status: encryption_status,
      data_quality_score: data_quality_score,
      change_significance: change_significance_score
    }
  end

  # === DATA QUALITY METHODS ===

  # Calculate initial data quality score for new records
  def calculate_initial_data_quality_score
    quality_factors = [
      completeness_score,
      validity_score,
      consistency_score,
      timeliness_score
    ]

    # Weighted average of quality factors
    weights = [0.3, 0.3, 0.2, 0.2]
    quality_factors.zip(weights).sum { |factor, weight| factor * weight }
  end

  # Recalculate data quality score after updates
  def recalculate_data_quality_score
    # Use existing score as baseline
    baseline_score = data_quality_score || 0.9

    # Apply penalties for data issues
    penalty_factors = calculate_quality_penalties

    # Apply improvements for fixes
    improvement_factors = calculate_quality_improvements

    # Calculate new score
    new_score = baseline_score - penalty_factors + improvement_factors
    [new_score, 0.0].max.round(3)
  end

  # === COMPLIANCE METHODS ===

  # Check if deletion is compliant with retention policy
  def deletion_compliant_with_retention_policy?
    return true unless data_classification.present?

    classification = DATA_CLASSIFICATIONS[data_classification.to_sym]
    return true unless classification[:retention]

    # Check if minimum retention period has been met
    minimum_age = classification[:retention]
    record_age = Time.current - created_at

    record_age >= minimum_age
  end

  # Handle data retention expiry
  def handle_retention_expiry
    case retention_action
    when :archive
      archive_for_retention
    when :anonymize
      anonymize_for_retention
    when :delete
      schedule_retention_deletion
    end
  end

  # === PERFORMANCE METHODS ===

  # Get default associations to include for performance
  def default_includes
    # Override in subclasses to define default eager loading
    []
  end

  # Get performance-specific associations to include
  def performance_includes
    # Override in subclasses for performance-optimized queries
    default_includes
  end

  # Check if field allows HTML content
  def field_allows_html?(field)
    # Override in subclasses to define HTML-allowed fields
    html_allowed_fields.include?(field)
  end

  # Get list of fields that allow HTML content
  def html_allowed_fields
    # Override in subclasses
    []
  end

  # Get list of sensitive fields requiring encryption
  def self.sensitive_fields
    # Override in subclasses to define sensitive fields
    []
  end

  # Check if organization context is required
  def organization_required?
    # Override in subclasses
    false
  end

  # Check if operation involves sensitive data
  def sensitive_data_operation?
    return true if sensitive_data_classification?

    # Check if any sensitive fields are being modified
    sensitive_fields = self.class.sensitive_fields || []
    sensitive_fields.any? { |field| attribute_changed?(field) }
  end

  # Check if data classification indicates sensitive data
  def sensitive_data_classification?
    sensitive_classifications = [:sensitive_personal, :sensitive_financial,
                               :sensitive_legal, :restricted_security]

    sensitive_classifications.include?(data_classification&.to_sym)
  end

  # === UTILITY METHODS ===

  # Generate comprehensive snapshot for backup/audit
  def generate_comprehensive_snapshot
    {
      record_data: attributes.compact,
      associations: serialize_associations,
      metadata: build_comprehensive_metadata,
      audit_info: audit_snapshot_info,
      security_info: security_snapshot_info,
      compliance_info: compliance_snapshot_info,
      performance_info: performance_snapshot_info
    }
  end

  # Serialize associated data for snapshot
  def serialize_associations
    # Implementation depends on specific associations
    # Override in subclasses for comprehensive serialization
    {}
  end

  # Build comprehensive metadata for the record
  def build_comprehensive_metadata
    {
      created_info: {
        by: created_by,
        at: created_at,
        ip: created_ip,
        user_agent: created_user_agent
      },
      updated_info: {
        by: updated_by,
        at: updated_at || last_updated_at,
        ip: updated_ip,
        user_agent: updated_user_agent
      },
      organization_context: organization_context_metadata,
      security_context: security_context_metadata,
      compliance_context: compliance_context_metadata,
      data_quality: data_quality_metadata
    }
  end

  # === ERROR HANDLING ===

  # Enhanced error handling with context
  def handle_enterprise_error(error, context = {})
    error_context = {
      model: self.class.name,
      record_id: id,
      operation: context[:operation],
      timestamp: Time.current,
      user_context: current_user_context,
      system_context: current_system_context
    }.merge(context)

    # Log enterprise error
    EnterpriseErrorService.log_error(error, error_context)

    # Trigger error notifications if critical
    trigger_critical_error_notifications(error, error_context) if critical_error?(error)

    # Create error recovery plan
    ErrorRecoveryService.create_recovery_plan(error, error_context)
  end

  # === PERFORMANCE MONITORING ===

  # Monitor current memory usage
  def current_memory_usage
    # Implementation depends on monitoring setup
    # This would typically use system monitoring tools
    0
  end

  # Get count of recorded database queries
  def recorded_query_count
    # Implementation depends on query monitoring setup
    0
  end

  # Get count of cache hits
  def recorded_cache_hits
    # Implementation depends on cache monitoring setup
    0
  end

  # === SEARCH INTEGRATION ===

  # Check if search is enabled for this model
  def search_enabled?
    # Override in subclasses or check global configuration
    defined?(Searchkick) && self.class.respond_to?(:searchkick)
  end

  # Update Elasticsearch indexes
  def update_elasticsearch_indexes
    return unless search_enabled?

    # Reindex the record
    reindex

    # Update related indexes if needed
    update_related_indexes
  end

  # Update external search service indexes
  def update_external_search_indexes
    # Implementation for external search services
    # Override in subclasses as needed
  end

  # Remove from search indexes
  def remove_from_search_indexes
    return unless search_enabled?

    # Remove from Elasticsearch
    remove_from_index

    # Remove from other search services
    remove_from_external_indexes
  end

  # === CACHING METHODS ===

  # Update dependent caches after changes
  def update_dependent_caches
    # Update model-level caches
    update_model_level_caches

    # Update related record caches
    update_related_record_caches

    # Update computed value caches
    update_computed_value_caches
  end

  # === VALIDATION HELPERS ===

  # Validate data integrity for the record
  def validate_data_integrity
    # Check referential integrity
    validate_referential_integrity

    # Check business rule compliance
    validate_business_rules

    # Check data consistency
    validate_data_consistency
  end

  # Validate field-level permissions
  def validate_field_level_permissions
    return unless Current.user

    # Check each changed field for permissions
    changed.each do |field|
      unless Current.user.can_modify_field?(self.class.name, field)
        errors.add(field, "cannot be modified")
      end
    end

    throw(:abort) if errors.any?
  end

  # Validate sensitive data change permissions
  def validate_sensitive_data_change_permissions
    return unless Current.user

    unless Current.user.has_sensitive_data_modification_permission?
      errors.add(:base, "Insufficient permissions for sensitive data modification")
      throw(:abort)
    end
  end

  # === HELPER METHODS ===

  # Check if record is locked for editing
  def locked_for_editing?
    return false unless column_names.include?('locked_at')

    locked_at.present? && locked_at > 24.hours.ago
  end

  # Check if record is owned by current user
  def owned_by_current_user?
    return false unless Current.user
    return false unless column_names.include?('user_id')

    user_id == Current.user.id
  end

  # Check if record has critical dependencies
  def has_critical_dependencies?
    # Check for dependencies that would be cascade deleted
    critical_associations = self.class.reflect_on_all_associations.select do |assoc|
      assoc.options[:dependent] == :restrict_with_exception ||
      assoc.options[:dependent] == :restrict_with_error
    end

    critical_associations.any? do |assoc|
      send(assoc.name).count > 0
    end
  end

  # Check if deletion is restricted
  def deletion_restricted?
    return true if column_names.include?('deletion_restricted') && deletion_restricted?

    # Check for other deletion restrictions
    return true if permanent_record? || system_record?
  end

  # Check if this is a permanent record that shouldn't be deleted
  def permanent_record?
    column_names.include?('permanent_record') && permanent_record?
  end

  # Check if this is a system record
  def system_record?
    column_names.include?('system_record') && system_record?
  end

  # Get retention action for this record
  def retention_action
    case data_classification&.to_sym
    when :sensitive_personal, :sensitive_financial then :archive
    when :sensitive_legal, :restricted_security then :archive
    else :delete
    end
  end

  # === INTEGRATION METHODS ===

  # Broadcast changes via ActionCable
  def broadcast_via_action_cable
    # Implementation for real-time updates
    # Override in subclasses for specific broadcasting
  end

  # Broadcast changes via WebSockets
  def broadcast_via_websockets
    # Implementation for WebSocket broadcasting
    # Override in subclasses as needed
  end

  # Trigger webhook notifications for external systems
  def trigger_webhook_notifications
    return unless webhook_notifications_enabled?

    # Trigger webhooks for configured events
    WebhookService.trigger_for_model_change(self)
  end

  # Propagate changes to external systems
  def propagate_changes_to_external_systems
    return unless external_integration_enabled?

    # Propagate to external APIs
    propagate_to_external_apis

    # Propagate to third-party services
    propagate_to_third_party_services

    # Update external data warehouses
    update_external_data_warehouses
  end

  # === COMPLIANCE METHODS ===

  # Archive record for retention compliance
  def archive_for_retention
    # Create archive record
    create_archive_record

    # Update status to archived
    update!(status: :archived, archived_at: Time.current)

    # Remove from active indexes
    remove_from_active_indexes
  end

  # Anonymize record for retention compliance
  def anonymize_for_retention
    # Anonymize sensitive fields
    anonymize_sensitive_fields

    # Update anonymization metadata
    update_anonymization_metadata

    # Keep record for compliance but anonymized
    save!
  end

  # Schedule deletion for retention compliance
  def schedule_retention_deletion
    # Schedule background job for deletion
    RetentionDeletionJob.perform_later(
      self.class.name,
      id,
      deletion_reason: :retention_policy
    )
  end

  # === METADATA METHODS ===

  # Extract system context for audit trails
  def extract_system_context
    {
      rails_version: Rails.version,
      ruby_version: RUBY_VERSION,
      server_info: server_identification,
      database_adapter: ActiveRecord::Base.connection.adapter_name,
      timestamp: Time.current
    }
  end

  # Extract business context for audit trails
  def extract_business_context
    {
      model: self.class.name,
      primary_key: self.class.primary_key,
      organization: organization&.name,
      data_classification: data_classification,
      compliance_flags: compliance_flags
    }
  end

  # Extract security context for audit trails
  def extract_security_context
    {
      encryption_enabled: encryption_required?,
      access_level: security_level,
      sensitive_data: sensitive_data_classification?,
      audit_required: compliance_required?,
      current_user_role: Current.user&.role
    }
  end

  # Get retention period for this record
  def get_retention_period
    return unless data_classification.present?

    DATA_CLASSIFICATIONS[data_classification.to_sym]&.dig(:retention)
  end

  # Get encryption status for the record
  def encryption_status
    {
      encryption_required: encryption_required?,
      encrypted_fields: encrypted_fields_list,
      encryption_algorithm: encryption_algorithm,
      last_encryption_check: last_encryption_check
    }
  end

  # === CACHE MANAGEMENT ===

  # Update model-level caches
  def update_model_level_caches
    # Clear model-specific caches
    Rails.cache.delete_matched(/#{self.class.name}:#{id}:*/)

    # Update class-level caches
    Rails.cache.delete("#{self.class.name}:counts")
    Rails.cache.delete("#{self.class.name}:summaries")
  end

  # Update related record caches
  def update_related_record_caches
    # Update caches for associated records
    associated_records_to_update.each do |record|
      record.clear_relevant_caches
    end
  end

  # Update computed value caches
  def update_computed_value_caches
    # Update cached computed values
    computed_values_to_cache.each do |cache_key, value|
      Rails.cache.write(cache_key, value, expires_in: cache_expiry_time)
    end
  end

  # === NOTIFICATION METHODS ===

  # Trigger creation notifications
  def trigger_creation_notifications
    return unless notifications_enabled?

    NotificationService.notify_record_creation(self)
  end

  # Trigger update notifications
  def trigger_update_notifications
    return unless notifications_enabled?

    NotificationService.notify_record_update(self, changed)
  end

  # Trigger deletion notifications
  def trigger_deletion_notifications
    return unless notifications_enabled?

    NotificationService.notify_record_deletion(self)
  end

  # Trigger rollback notifications
  def trigger_rollback_notifications
    return unless notifications_enabled?

    NotificationService.notify_rollback(self)
  end

  # === CONFIGURATION METHODS ===

  # Check if audit trail is enabled for this model
  def audit_trail_enabled?
    # Override in subclasses or check global configuration
    true
  end

  # Check if change tracking is enabled
  def change_tracking_enabled?
    # Override in subclasses or check global configuration
    true
  end

  # Check if real-time updates are enabled
  def real_time_updates_enabled?
    # Override in subclasses or check global configuration
    false
  end

  # Check if notifications are enabled
  def notifications_enabled?
    # Override in subclasses or check global configuration
    true
  end

  # Check if webhook notifications are enabled
  def webhook_notifications_enabled?
    # Override in subclasses or check global configuration
    false
  end

  # Check if external integration is enabled
  def external_integration_enabled?
    # Override in subclasses or check global configuration
    false
  end

  # Check if archiving is required for compliance
  def archiving_required?
    compliance_required? || sensitive_data?
  end

  # Check if record requires encryption
  def requires_encryption?
    return true if sensitive_data_classification?

    # Check field-level encryption requirements
    sensitive_fields = self.class.sensitive_fields || []
    sensitive_fields.any? { |field| attribute_present?(field) }
  end

  # === PERFORMANCE THRESHOLDS ===

  # Trigger performance alerts if thresholds exceeded
  def trigger_performance_alerts(execution_time)
    thresholds = PERFORMANCE_THRESHOLDS

    if execution_time > thresholds[:very_slow_query][:threshold_ms].milliseconds
      trigger_critical_performance_alert(execution_time)
    elsif execution_time > thresholds[:slow_query][:threshold_ms].milliseconds
      trigger_performance_warning(execution_time)
    end
  end

  # Trigger critical performance alert
  def trigger_critical_performance_alert(execution_time)
    PerformanceAlertService.alert_critical(
      model: self.class.name,
      record_id: id,
      execution_time: execution_time,
      threshold: PERFORMANCE_THRESHOLDS[:very_slow_query][:threshold_ms],
      context: performance_context
    )
  end

  # Trigger performance warning
  def trigger_performance_warning(execution_time)
    PerformanceAlertService.alert_warning(
      model: self.class.name,
      record_id: id,
      execution_time: execution_time,
      threshold: PERFORMANCE_THRESHOLDS[:slow_query][:threshold_ms],
      context: performance_context
    )
  end

  # === CALCULATION METHODS ===

  # Calculate change significance score
  def calculate_change_significance_score
    # Base score on field importance and change magnitude
    significance_factors = changed.map do |field|
      field_importance_score(field) * change_magnitude_score(field)
    end

    # Weighted average of significance factors
    significance_factors.sum.to_f / significance_factors.count
  end

  # Calculate field importance score
  def field_importance_score(field)
    # Define field importance based on business rules
    importance_map = {
      'status' => 0.9,
      'amount' => 0.8,
      'name' => 0.7,
      'email' => 0.8,
      'created_at' => 0.3,
      'updated_at' => 0.2
    }

    importance_map[field.to_s] || 0.5
  end

  # Calculate change magnitude score for a field
  def change_magnitude_score(field)
    old_value = attribute_was(field)
    new_value = send(field)

    # Calculate magnitude based on field type and change
    case column_for_attribute(field)&.type
    when :boolean
      old_value != new_value ? 1.0 : 0.0
    when :decimal, :integer, :float
      calculate_numeric_change_magnitude(old_value, new_value)
    when :string, :text
      calculate_text_change_magnitude(old_value, new_value)
    when :datetime, :date
      calculate_date_change_magnitude(old_value, new_value)
    else
      0.5
    end
  end

  # Calculate numeric change magnitude
  def calculate_numeric_change_magnitude(old_value, new_value)
    return 0.0 if old_value.blank? && new_value.blank?

    if old_value.blank?
      1.0 # New value added
    elsif new_value.blank?
      0.8 # Value removed
    else
      change_ratio = (new_value.to_f - old_value.to_f).abs / old_value.to_f.abs
      [change_ratio, 1.0].min
    end
  end

  # Calculate text change magnitude
  def calculate_text_change_magnitude(old_value, new_value)
    return 0.0 if old_value.blank? && new_value.blank?

    if old_value.blank?
      0.8 # New text added
    elsif new_value.blank?
      0.7 # Text removed
    else
      # Calculate text similarity
      similarity = TextSimilarityService.calculate_similarity(old_value, new_value)
      1.0 - similarity # Higher score for more different text
    end
  end

  # Calculate date change magnitude
  def calculate_date_change_magnitude(old_value, new_value)
    return 0.0 if old_value.blank? && new_value.blank?

    if old_value.blank?
      0.6 # New date added
    elsif new_value.blank?
      0.5 # Date removed
    else
      # Calculate time difference
      time_diff = (new_value - old_value).abs
      time_diff_days = time_diff / 1.day

      # Score based on time difference magnitude
      case time_diff_days
      when 0..1 then 0.2
      when 1..7 then 0.4
      when 7..30 then 0.6
      when 30..365 then 0.8
      else 1.0
      end
    end
  end

  # === RISK ASSESSMENT ===

  # Calculate risk score for audit events
  def calculate_audit_risk_score(event, changes)
    risk_factors = [
      event_risk_factor(event),
      changes_risk_factor(changes),
      data_sensitivity_risk_factor,
      user_risk_factor,
      timing_risk_factor
    ]

    # Weighted average of risk factors
    weights = [0.3, 0.3, 0.2, 0.15, 0.05]
    risk_factors.zip(weights).sum { |factor, weight| factor * weight }
  end

  # Calculate risk factor for audit event type
  def event_risk_factor(event)
    risk_levels = {
      create: 0.1,
      update: 0.3,
      destroy: 0.8,
      bulk_operation: 0.9,
      security_event: 1.0
    }

    risk_levels[event.to_sym] || 0.5
  end

  # Calculate risk factor based on changes made
  def changes_risk_factor(changes)
    return 0.1 if changes.blank?

    # Higher risk for more changes or sensitive field changes
    sensitive_fields_changed = changes.keys & (self.class.sensitive_fields || []).map(&:to_s)
    change_count = changes.keys.count

    base_risk = change_count * 0.1
    sensitive_penalty = sensitive_fields_changed.count * 0.3

    [base_risk + sensitive_penalty, 1.0].min
  end

  # Calculate risk factor based on data sensitivity
  def data_sensitivity_risk_factor
    sensitivity_levels = {
      public_data: 0.0,
      internal_use: 0.2,
      sensitive_personal: 0.7,
      sensitive_financial: 0.8,
      sensitive_legal: 0.9,
      restricted_security: 1.0,
      confidential_commercial: 1.0
    }

    sensitivity_levels[data_classification&.to_sym] || 0.3
  end

  # Calculate risk factor based on user context
  def user_risk_factor
    return 0.1 unless Current.user

    case Current.user.role&.to_sym
    when :admin, :super_admin then 0.2
    when :manager then 0.4
    when :user then 0.6
    else 0.8
    end
  end

  # Calculate risk factor based on timing
  def timing_risk_factor
    hour = Time.current.hour

    case hour
    when 9..17 then 0.2  # Business hours - lower risk
    when 6..8, 18..21 then 0.4  # Extended hours - medium risk
    else 0.6  # Off hours - higher risk
    end
  end

  # === FINALIZATION ===

  # Database indexes for optimal performance across all models
  # (These would typically be added via migrations)

  # Global indexes that apply to common patterns across models
  # Note: These are template indexes - actual indexes should be added via migrations

  # Common timestamp indexes
  # index :created_at
  # index :updated_at
  # index [:created_at, :updated_at]

  # Common status and state indexes
  # index :status if column_names.include?('status')
  # index :active if column_names.include?('active')
  # index [:status, :active]

  # Organization context indexes
  # index :organization_id if column_names.include?('organization_id')
  # index [:organization_id, :created_at]

  # User context indexes
  # index :user_id if column_names.include?('user_id')
  # index [:user_id, :created_at]

  # Data classification indexes
  # index :data_classification if column_names.include?('data_classification')
  # index :security_level if column_names.include?('security_level')
end
