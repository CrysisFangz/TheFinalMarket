# frozen_string_literal: true

# Enterprise Audit Module providing comprehensive audit trails, change tracking,
# and compliance logging capabilities for ActiveRecord models
#
# @author Kilo Code Autonomous Agent
# @version 3.0.0
# @since 2025-10-22
#
module EnterpriseModules
  # Audit Module for enterprise-grade audit trail features
  module AuditModule
    # === CONSTANTS ===

    # Audit event types and their configurations
    AUDIT_EVENT_TYPES = {
      create: {
        severity: :low,
        retention: 3.years,
        compliance_flags: [],
        description: "Record creation"
      },
      update: {
        severity: :low,
        retention: 3.years,
        compliance_flags: [],
        description: "Record modification"
      },
      destroy: {
        severity: :medium,
        retention: 7.years,
        compliance_flags: [:gdpr],
        description: "Record deletion"
      },
      access: {
        severity: :low,
        retention: 1.year,
        compliance_flags: [],
        description: "Record access"
      },
      bulk_operation: {
        severity: :high,
        retention: 5.years,
        compliance_flags: [:audit_required],
        description: "Bulk data operation"
      },
      security_event: {
        severity: :critical,
        retention: 10.years,
        compliance_flags: [:sox, :pci_dss],
        description: "Security-related event"
      },
      compliance_event: {
        severity: :medium,
        retention: 7.years,
        compliance_flags: [:gdpr, :sox],
        description: "Compliance-related event"
      },
      data_quality_event: {
        severity: :low,
        retention: 2.years,
        compliance_flags: [],
        description: "Data quality assessment"
      }
    }.freeze

    # Audit levels for different compliance requirements
    AUDIT_LEVELS = {
      minimal: {
        track_changes: false,
        track_access: false,
        track_performance: false,
        retention: 90.days
      },
      basic: {
        track_changes: true,
        track_access: false,
        track_performance: false,
        retention: 1.year
      },
      standard: {
        track_changes: true,
        track_access: true,
        track_performance: false,
        retention: 3.years
      },
      comprehensive: {
        track_changes: true,
        track_access: true,
        track_performance: true,
        retention: 5.years
      },
      maximum: {
        track_changes: true,
        track_access: true,
        track_performance: true,
        retention: 10.years
      }
    }.freeze

    # === MODULE METHODS ===

    # Extend base class with audit features
    def self.extended(base)
      base.class_eval do
        # Include audit associations
        include_audit_associations

        # Include audit validations
        include_audit_validations

        # Include audit callbacks
        include_audit_callbacks

        # Include audit scopes
        include_audit_scopes

        # Initialize audit configuration
        initialize_audit_configuration
      end
    end

    private

    # Include audit-related associations
    def include_audit_associations
      # Audit trail associations
      has_many :audit_logs, class_name: 'ModelAuditLog', dependent: :destroy if defined?(ModelAuditLog)
      has_many :change_histories, class_name: 'ModelChangeHistory', dependent: :destroy if defined?(ModelChangeHistory)
      has_many :audit_events, class_name: 'ModelAuditEvent', dependent: :destroy if defined?(ModelAuditEvent)

      # Change tracking associations
      has_many :field_changes, class_name: 'ModelFieldChange', dependent: :destroy if defined?(ModelFieldChange)
      has_many :relationship_changes, class_name: 'ModelRelationshipChange', dependent: :destroy if defined?(ModelRelationshipChange)
    end

    # Include audit validations
    def include_audit_validations
      # Audit configuration validations
      validates :audit_level, inclusion: {
        in: AUDIT_LEVELS.keys.map(&:to_s)
      }, allow_nil: true if column_names.include?('audit_level')

      validates :change_tracking_enabled, inclusion: {
        in: [true, false]
      }, allow_nil: true if column_names.include?('change_tracking_enabled')

      validates :audit_retention_period, numericality: {
        greater_than: 0,
        less_than_or_equal_to: 10.years
      }, allow_nil: true if column_names.include?('audit_retention_period')
    end

    # Include audit callbacks
    def include_audit_callbacks
      # Audit trail callbacks
      before_create :initialize_audit_trail, :setup_audit_context
      before_update :validate_audit_permissions, :capture_pre_change_state
      before_destroy :validate_deletion_audit, :create_deletion_audit_trail

      # Change tracking callbacks
      after_create :create_creation_audit_log, :track_initial_state
      after_update :create_update_audit_log, :track_field_changes
      after_destroy :create_deletion_audit_log, :cleanup_audit_trail

      # Audit maintenance callbacks
      after_commit :update_audit_indexes, :trigger_audit_notifications
      after_rollback :handle_audit_rollback
    end

    # Include audit scopes
    def include_audit_scopes
      scope :recently_audited, ->(timeframe = 7.days) {
        joins(:audit_logs).where('audit_logs.created_at > ?', timeframe.ago).distinct
      }

      scope :high_audit_activity, -> {
        joins(:audit_logs).group('audit_logs.auditable_id').
        having('COUNT(audit_logs.id) > ?', 10).distinct
      }

      scope :critical_audit_events, -> {
        joins(:audit_logs).where('audit_logs.severity IN (?)', [:high, :critical])
      }

      scope :compliance_audit_required, -> {
        joins(:audit_logs).where('audit_logs.compliance_flags IS NOT NULL').distinct
      }
    end

    # Initialize audit configuration
    def initialize_audit_configuration
      @audit_config = audit_level_config
      @change_tracking_config = change_tracking_configuration
      @audit_retention_config = audit_retention_configuration
    end

    # === AUDIT LOGGING METHODS ===

    # Create comprehensive audit log entry
    def create_audit_log_entry(event:, changes: {}, user: nil, context: {}, metadata: {})
      return unless audit_enabled?

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
        severity: AUDIT_EVENT_TYPES[event.to_sym]&.dig(:severity) || :low,
        created_at: Time.current
      )
    end

    # Create audit log for record creation
    def create_creation_audit_log
      return unless audit_enabled?

      create_audit_log_entry(
        event: :create,
        changes: attributes.compact,
        user: Current.user,
        context: build_creation_audit_context,
        metadata: build_creation_audit_metadata
      )
    end

    # Create audit log for record update
    def create_update_audit_log
      return unless audit_enabled? && changed?

      create_audit_log_entry(
        event: :update,
        changes: changes_with_values,
        user: Current.user,
        context: build_update_audit_context,
        metadata: build_update_audit_metadata
      )
    end

    # Create audit log for record deletion
    def create_deletion_audit_log
      return unless audit_enabled?

      create_audit_log_entry(
        event: :destroy,
        changes: { deleted_attributes: attributes.compact },
        user: Current.user,
        context: build_deletion_audit_context,
        metadata: build_deletion_audit_metadata
      )
    end

    # === CHANGE TRACKING METHODS ===

    # Track initial state for new records
    def track_initial_state
      return unless change_tracking_enabled?

      # Create initial field state records
      attribute_names.each do |field|
        next unless attribute_present?(field)

        field_changes.create!(
          field_name: field,
          old_value: nil,
          new_value: send(field),
          change_type: :initial,
          user: Current.user,
          created_at: Time.current
        )
      end
    end

    # Track field changes after update
    def track_field_changes
      return unless change_tracking_enabled? && changed?

      changed.each do |field|
        next unless track_field_change?(field)

        field_changes.create!(
          field_name: field,
          old_value: attribute_was(field),
          new_value: send(field),
          change_type: :update,
          user: Current.user,
          change_significance: calculate_field_change_significance(field),
          created_at: Time.current
        )
      end
    end

    # Capture pre-change state for comparison
    def capture_pre_change_state
      return unless change_tracking_enabled?

      @pre_change_attributes = attributes.dup
      @pre_change_associations = capture_association_states
    end

    # === AUDIT CONTEXT METHODS ===

    # Build comprehensive audit context
    def build_audit_context
      {
        model_name: self.class.name,
        record_id: id,
        operation_type: new_record? ? :create : :update,
        timestamp: Time.current,
        system_context: extract_system_context,
        business_context: extract_business_context,
        security_context: extract_security_context,
        performance_context: extract_performance_context
      }
    end

    # Build creation-specific audit context
    def build_creation_audit_context
      build_audit_context.merge(
        operation_type: :create,
        initial_state: attributes.compact,
        creation_method: creation_method
      )
    end

    # Build update-specific audit context
    def build_update_audit_context
      build_audit_context.merge(
        operation_type: :update,
        previous_state: @pre_change_attributes,
        change_summary: generate_change_summary
      )
    end

    # Build deletion-specific audit context
    def build_deletion_audit_context
      build_audit_context.merge(
        operation_type: :delete,
        final_state: attributes.compact,
        deletion_reason: deletion_reason,
        cascade_effects: cascade_deletion_effects
      )
    end

    # === AUDIT METADATA METHODS ===

    # Build comprehensive audit metadata
    def build_audit_metadata
      {
        data_classification: data_classification,
        compliance_flags: compliance_flags,
        retention_period: get_retention_period,
        encryption_status: encryption_status,
        data_quality_score: data_quality_score,
        change_significance: change_significance_score,
        audit_config: @audit_config
      }
    end

    # Build creation-specific audit metadata
    def build_creation_audit_metadata
      build_audit_metadata.merge(
        initial_data_quality: calculate_initial_data_quality_score,
        creation_source: creation_source,
        initial_compliance_status: initial_compliance_status
      )
    end

    # Build update-specific audit metadata
    def build_update_audit_metadata
      build_audit_metadata.merge(
        change_impact: calculate_change_impact,
        data_quality_change: calculate_data_quality_change,
        compliance_impact: calculate_compliance_impact
      )
    end

    # Build deletion-specific audit metadata
    def build_deletion_audit_metadata
      build_audit_metadata.merge(
        deletion_compliance_check: deletion_compliance_check,
        data_retention_status: data_retention_status,
        archival_requirements: archival_requirements
      )
    end

    # === VALIDATION METHODS ===

    # Validate audit permissions before update
    def validate_audit_permissions
      return unless audit_enabled? && change_tracking_enabled?

      # Check if user can modify this record
      unless current_user_can_modify_record?
        errors.add(:base, "Insufficient permissions to modify this record")
        throw(:abort)
      end

      # Validate field-level audit permissions
      validate_field_audit_permissions

      # Check for sensitive data changes requiring enhanced audit
      if sensitive_data_changes?
        validate_sensitive_data_audit_permissions
      end
    end

    # Validate field-level audit permissions
    def validate_field_audit_permissions
      return unless Current.user

      changed.each do |field|
        unless current_user_can_audit_field?(field)
          errors.add(field, "cannot be modified - audit restrictions apply")
        end
      end

      throw(:abort) if errors.any?
    end

    # Validate sensitive data audit permissions
    def validate_sensitive_data_audit_permissions
      return unless Current.user

      unless Current.user.has_sensitive_data_audit_permission?
        errors.add(:base, "Insufficient permissions for sensitive data audit")
        throw(:abort)
      end
    end

    # Validate deletion audit requirements
    def validate_deletion_audit
      return unless audit_enabled? && persisted?

      # Check if deletion audit is required
      unless deletion_audit_compliant?
        errors.add(:base, "Deletion audit requirements not met")
        throw(:abort)
      end

      # Validate retention policy compliance for audit
      unless deletion_audit_retention_compliant?
        errors.add(:base, "Deletion violates audit retention policy")
        throw(:abort)
      end
    end

    # === UTILITY METHODS ===

    # Check if audit is enabled for this model
    def audit_enabled?
      @audit_config[:track_changes] || false
    end

    # Check if change tracking is enabled
    def change_tracking_enabled?
      return false unless column_names.include?('change_tracking_enabled')

      change_tracking_enabled? && @change_tracking_config[:enabled]
    end

    # Check if access tracking is enabled
    def access_tracking_enabled?
      @audit_config[:track_access] || false
    end

    # Check if performance tracking is enabled
    def performance_tracking_enabled?
      @audit_config[:track_performance] || false
    end

    # Check if field change should be tracked
    def track_field_change?(field)
      # Don't track technical fields unless specifically configured
      technical_fields = ['updated_at', 'last_accessed_at', 'lock_version']
      return false if technical_fields.include?(field)

      # Track all other fields
      true
    end

    # Get changes with old and new values
    def changes_with_values
      changed.map do |field|
        {
          field => {
            old: attribute_was(field),
            new: send(field),
            changed_at: Time.current
          }
        }
      end.reduce({}, :merge)
    end

    # Generate change summary for audit context
    def generate_change_summary
      {
        fields_changed: changed.count,
        significant_changes: significant_changes.count,
        sensitive_fields_changed: sensitive_fields_changed.count,
        change_complexity: calculate_change_complexity
      }
    end

    # Get significant changes (fields with high importance)
    def significant_changes
      changed.select do |field|
        field_importance_score(field) > 0.7
      end
    end

    # Get sensitive fields that were changed
    def sensitive_fields_changed
      changed & (self.class.sensitive_fields || [])
    end

    # Calculate field importance score
    def field_importance_score(field)
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

    # Calculate change complexity
    def calculate_change_complexity
      complexity_factors = [
        changed.count * 0.1,
        significant_changes.count * 0.3,
        sensitive_fields_changed.count * 0.4
      ]

      complexity_factors.sum
    end

    # === RISK ASSESSMENT METHODS ===

    # Calculate audit risk score for events
    def calculate_audit_risk_score(event, changes)
      risk_factors = [
        event_risk_factor(event),
        changes_risk_factor(changes),
        data_sensitivity_risk_factor,
        user_risk_factor,
        timing_risk_factor,
        context_risk_factor(changes)
      ]

      # Weighted average of risk factors
      weights = [0.25, 0.25, 0.2, 0.15, 0.05, 0.1]
      risk_factors.zip(weights).sum { |factor, weight| factor * weight }
    end

    # Calculate risk factor for audit event type
    def event_risk_factor(event)
      risk_levels = {
        create: 0.1,
        update: 0.3,
        destroy: 0.8,
        access: 0.2,
        bulk_operation: 0.9,
        security_event: 1.0,
        compliance_event: 0.7,
        data_quality_event: 0.4
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

    # Calculate risk factor based on change context
    def context_risk_factor(changes)
      risk_score = 0.0

      # High risk if significant fields are changed
      if significant_changes.any?
        risk_score += 0.3
      end

      # High risk for bulk operations
      if changes[:bulk_operation]
        risk_score += 0.4
      end

      # High risk for system-level changes
      if changes[:system_operation]
        risk_score += 0.2
      end

      risk_score
    end

    # === CONFIGURATION METHODS ===

    # Get audit level configuration
    def audit_level_config
      level = enterprise_module_config(:audit)[:level] || :standard
      AUDIT_LEVELS[level.to_sym] || AUDIT_LEVELS[:standard]
    end

    # Get change tracking configuration
    def change_tracking_configuration
      {
        enabled: change_tracking_enabled?,
        track_all_fields: track_all_fields?,
        track_associations: track_associations?,
        track_performance: performance_tracking_enabled?,
        retention_period: audit_retention_period
      }
    end

    # Get audit retention configuration
    def audit_retention_configuration
      {
        default_retention: @audit_config[:retention],
        compliance_retention: compliance_audit_retention,
        critical_event_retention: critical_event_retention,
        cleanup_schedule: audit_cleanup_schedule
      }
    end

    # === COMPLIANCE METHODS ===

    # Generate comprehensive audit trail
    def generate_audit_trail(**options)
      audit_service = AuditTrailService.new(self)

      audit_service.generate_comprehensive_trail(
        include_changes: options[:include_changes] || true,
        include_context: options[:include_context] || true,
        include_security: options[:include_security] || true,
        include_performance: options[:include_performance] || performance_tracking_enabled?,
        timeframe: options[:timeframe] || 30.days,
        compliance_flags: options[:compliance_flags] || []
      )
    end

    # Check audit retention compliance
    def check_audit_retention_compliance
      return unless audit_enabled?

      # Check if audit logs exceed retention period
      old_audit_logs = audit_logs.where('created_at < ?', audit_retention_period.ago)

      if old_audit_logs.exists?
        handle_audit_retention_expiry(old_audit_logs)
      end
    end

    # Handle audit retention expiry
    def handle_audit_retention_expiry(old_logs)
      case audit_retention_action
      when :archive
        archive_audit_logs(old_logs)
      when :summarize
        summarize_audit_logs(old_logs)
      when :delete
        delete_audit_logs(old_logs)
      end
    end

    # === HELPER METHODS ===

    # Check if user can audit a specific field
    def current_user_can_audit_field?(field)
      return true unless Current.user

      # Check field-specific audit permissions
      Current.user.can_audit_field?(self.class.name, field)
    end

    # Check if field change is significant
    def calculate_field_change_significance(field)
      old_value = attribute_was(field)
      new_value = send(field)

      # Calculate significance based on field type and change magnitude
      change_magnitude = calculate_change_magnitude(field, old_value, new_value)
      field_importance = field_importance_score(field)

      change_magnitude * field_importance
    end

    # Calculate change magnitude for a field
    def calculate_change_magnitude(field, old_value, new_value)
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
        # Calculate text similarity (simplified implementation)
        similarity = calculate_text_similarity(old_value, new_value)
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

    # Calculate text similarity (simplified)
    def calculate_text_similarity(old_text, new_text)
      # Simple implementation - in practice, would use more sophisticated algorithms
      return 1.0 if old_text == new_text

      old_words = old_text.to_s.downcase.split
      new_words = new_text.to_s.downcase.split

      return 0.0 if old_words.empty? && new_words.empty?

      common_words = old_words & new_words
      total_words = old_words | new_words

      common_words.count.to_f / total_words.count
    end

    # === ROLLBACK HANDLING ===

    # Handle audit rollback events
    def handle_audit_rollback
      create_audit_log_entry(
        event: :audit_rollback,
        changes: { reason: :transaction_rollback },
        context: { rollback_timestamp: Time.current }
      )
    end

    # === CLEANUP METHODS ===

    # Cleanup audit trail after deletion
    def cleanup_audit_trail
      return unless audit_enabled?

      # Archive audit logs if required by compliance
      if deletion_audit_archival_required?
        archive_audit_logs_for_deletion
      end

      # Remove audit logs if permitted by retention policy
      if deletion_audit_cleanup_permitted?
        remove_audit_logs_for_deleted_record
      end
    end

    # === NOTIFICATION METHODS ===

    # Trigger audit notifications
    def trigger_audit_notifications
      return unless audit_notifications_enabled?

      # Notify about critical audit events
      if critical_audit_events_pending?
        notify_critical_audit_events
      end

      # Notify about compliance audit requirements
      if compliance_audit_notifications_required?
        notify_compliance_audit_requirements
      end
    end

    # Check if audit notifications are enabled
    def audit_notifications_enabled?
      @audit_config[:track_access] && notifications_enabled?
    end

    # === INDEXING METHODS ===

    # Update audit indexes
    def update_audit_indexes
      return unless audit_indexing_enabled?

      # Update audit search indexes
      update_audit_search_indexes

      # Update audit analytics indexes
      update_audit_analytics_indexes
    end

    # Check if audit indexing is enabled
    def audit_indexing_enabled?
      @audit_config[:track_performance] || false
    end

    # === COMPLIANCE VALIDATION ===

    # Check if deletion audit is compliant
    def deletion_audit_compliant?
      return true unless audit_enabled?

      # Check if minimum audit retention period has been met
      minimum_audit_age = minimum_audit_retention_period
      record_age = Time.current - created_at

      record_age >= minimum_audit_age
    end

    # Check if deletion audit retention is compliant
    def deletion_audit_retention_compliant?
      return true unless audit_enabled?

      # Check audit retention requirements for deletion
      audit_retention_days = audit_retention_period
      last_audit_age = Time.current - last_audit_log_date

      last_audit_age <= audit_retention_days
    end

    # === CONFIGURATION HELPERS ===

    # Check if track all fields is enabled
    def track_all_fields?
      column_names.include?('track_all_fields') && track_all_fields?
    end

    # Check if track associations is enabled
    def track_associations?
      column_names.include?('track_associations') && track_associations?
    end

    # Get audit retention period
    def audit_retention_period
      return @audit_retention_config[:default_retention] if @audit_retention_config

      column_names.include?('audit_retention_period') ? self.audit_retention_period : 3.years
    end

    # Get compliance audit retention
    def compliance_audit_retention
      7.years # Standard compliance retention period
    end

    # Get critical event retention
    def critical_event_retention
      10.years # Critical events require longer retention
    end

    # Get audit cleanup schedule
    def audit_cleanup_schedule
      :monthly # Default cleanup schedule
    end

    # Get minimum audit retention period
    def minimum_audit_retention_period
      90.days # Minimum period for audit compliance
    end

    # Get last audit log date
    def last_audit_log_date
      audit_logs.maximum(:created_at) || created_at
    end

    # === ARCHIVAL METHODS ===

    # Archive audit logs for retention compliance
    def archive_audit_logs(old_logs)
      # Create audit archive record
      create_audit_archive_record(old_logs)

      # Update status to archived
      old_logs.update_all(status: :archived, archived_at: Time.current)
    end

    # Summarize audit logs for retention compliance
    def summarize_audit_logs(old_logs)
      # Create audit summary record
      create_audit_summary_record(old_logs)

      # Remove detailed logs but keep summary
      old_logs.delete_all
    end

    # Delete audit logs for retention compliance
    def delete_audit_logs(old_logs)
      # Create deletion record before deleting
      create_audit_deletion_record(old_logs)

      # Delete old logs
      old_logs.delete_all
    end

    # === CONTEXT EXTRACTION METHODS ===

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

    # Extract performance context for audit trails
    def extract_performance_context
      {
        query_count: recorded_query_count,
        execution_time: current_execution_time,
        memory_usage: current_memory_usage,
        cache_hits: recorded_cache_hits
      }
    end

    # === STATE CAPTURE METHODS ===

    # Capture association states for change tracking
    def capture_association_states
      # Implementation depends on specific associations
      # Override in subclasses for comprehensive association tracking
      {}
    end

    # Get creation method (how the record was created)
    def creation_method
      new_record? ? :new : :existing
    end

    # Get creation source
    def creation_source
      case
      when import_job.present? then :import
      when api_creation? then :api
      when user_creation? then :user_interface
      else :system
      end
    end

    # === COMPLIANCE CALCULATIONS ===

    # Calculate change impact for audit
    def calculate_change_impact
      {
        business_impact: calculate_business_impact,
        compliance_impact: calculate_compliance_impact,
        security_impact: calculate_security_impact,
        data_quality_impact: calculate_data_quality_impact
      }
    end

    # Calculate business impact of changes
    def calculate_business_impact
      # Implementation depends on business rules
      # Override in subclasses
      :low
    end

    # Calculate compliance impact of changes
    def calculate_compliance_impact
      # Implementation depends on compliance requirements
      # Override in subclasses
      :low
    end

    # Calculate security impact of changes
    def calculate_security_impact
      # Implementation depends on security requirements
      # Override in subclasses
      :low
    end

    # Calculate data quality impact of changes
    def calculate_data_quality_impact
      # Implementation depends on data quality rules
      # Override in subclasses
      :low
    end

    # === INITIALIZATION METHODS ===

    # Initialize audit trail for new records
    def initialize_audit_trail
      return unless audit_enabled?

      # Set creation metadata
      self.created_by ||= Current.user&.id
      self.created_ip ||= Current.ip_address
      self.created_user_agent ||= Current.user_agent

      # Initialize audit trail
      self.audit_trail_enabled ||= true
      self.change_tracking_enabled ||= true

      # Set initial data quality score
      self.data_quality_score ||= calculate_initial_data_quality_score
    end

    # Setup audit context for new records
    def setup_audit_context
      return unless audit_enabled?

      # Set initial audit metadata
      self.audit_level ||= :standard
      self.audit_retention_period ||= 3.years

      # Set audit compliance flags
      self.audit_compliance_flags ||= []
    end

    # === DELETION METHODS ===

    # Create comprehensive deletion audit trail
    def create_deletion_audit_trail
      return unless audit_enabled?

      create_audit_log_entry(
        event: :destroy,
        changes: { deleted_attributes: attributes.compact },
        user: Current.user,
        context: {
          deletion_reason: deletion_reason,
          cascade_effects: cascade_deletion_effects,
          compliance_check: deletion_compliance_check
        },
        metadata: build_deletion_audit_metadata
      )
    end

    # === NOTIFICATION HELPERS ===

    # Check if critical audit events are pending
    def critical_audit_events_pending?
      audit_logs.where(severity: [:high, :critical]).where('created_at > ?', 1.hour.ago).exists?
    end

    # Check if compliance audit notifications are required
    def compliance_audit_notifications_required?
      audit_logs.where('compliance_flags IS NOT NULL').where('created_at > ?', 24.hours.ago).exists?
    end

    # === PLACEHOLDER METHODS FOR OVERRIDE ===

    # These methods can be overridden in subclasses for specific behavior

    # Check if notifications are enabled
    def notifications_enabled?
      true # Override in subclasses
    end

    # Get recorded query count
    def recorded_query_count
      0 # Override in subclasses with actual implementation
    end

    # Get current execution time
    def current_execution_time
      0 # Override in subclasses with actual implementation
    end

    # Get current memory usage
    def current_memory_usage
      0 # Override in subclasses with actual implementation
    end

    # Get recorded cache hits
    def recorded_cache_hits
      0 # Override in subclasses with actual implementation
    end

    # Check if record requires encryption
    def encryption_required?
      false # Override in subclasses
    end

    # Check if record has sensitive data classification
    def sensitive_data_classification?
      false # Override in subclasses
    end

    # Get data classification
    def data_classification
      nil # Override in subclasses
    end

    # Get compliance flags
    def compliance_flags
      [] # Override in subclasses
    end

    # Get security level
    def security_level
      :standard # Override in subclasses
    end

    # Get deletion reason
    def deletion_reason
      :user_requested # Override in subclasses
    end

    # Get cascade deletion effects
    def cascade_deletion_effects
      {} # Override in subclasses
    end

    # Get deletion compliance check
    def deletion_compliance_check
      {} # Override in subclasses
    end

    # Check if deletion audit archival is required
    def deletion_audit_archival_required?
      compliance_required? || sensitive_data_classification?
    end

    # Check if deletion audit cleanup is permitted
    def deletion_audit_cleanup_permitted?
      !deletion_audit_archival_required?
    end

    # Check if compliance is required
    def compliance_required?
      false # Override in subclasses
    end

    # Get initial compliance status
    def initial_compliance_status
      :compliant # Override in subclasses
    end

    # Calculate initial data quality score
    def calculate_initial_data_quality_score
      0.9 # Override in subclasses with actual implementation
    end

    # Get server identification
    def server_identification
      Rails.env # Override in subclasses with actual server info
    end

    # Check if import job is present
    def import_job
      nil # Override in subclasses
    end

    # Check if API creation
    def api_creation?
      false # Override in subclasses
    end

    # Check if user creation
    def user_creation?
      true # Override in subclasses
    end

    # Get audit retention action
    def audit_retention_action
      :archive # Override in subclasses
    end

    # Create audit archive record
    def create_audit_archive_record(old_logs)
      # Implementation for creating archive records
    end

    # Create audit summary record
    def create_audit_summary_record(old_logs)
      # Implementation for creating summary records
    end

    # Create audit deletion record
    def create_audit_deletion_record(old_logs)
      # Implementation for creating deletion records
    end

    # Archive audit logs for deletion
    def archive_audit_logs_for_deleted_record
      # Implementation for archiving audit logs when record is deleted
    end

    # Remove audit logs for deleted record
    def remove_audit_logs_for_deleted_record
      # Implementation for removing audit logs when record is deleted
    end

    # Notify critical audit events
    def notify_critical_audit_events
      # Implementation for critical audit event notifications
    end

    # Notify compliance audit requirements
    def notify_compliance_audit_requirements
      # Implementation for compliance audit notifications
    end

    # Update audit search indexes
    def update_audit_search_indexes
      # Implementation for updating audit search indexes
    end

    # Update audit analytics indexes
    def update_audit_analytics_indexes
      # Implementation for updating audit analytics indexes
    end
  end
end