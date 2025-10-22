# frozen_string_literal: true

# Enterprise Security Module providing comprehensive security, encryption,
# permissions, and access control capabilities for ActiveRecord models
#
# @author Kilo Code Autonomous Agent
# @version 3.0.0
# @since 2025-10-22
#
module EnterpriseModules
  # Security Module for enterprise-grade security features
  module SecurityModule
    # === CONSTANTS ===

    # Security levels for different compliance requirements
    SECURITY_LEVELS = {
      basic: {
        encryption_enabled: false,
        audit_level: :minimal,
        access_control: :standard,
        input_sanitization: :basic
      },
      standard: {
        encryption_enabled: true,
        audit_level: :standard,
        access_control: :enhanced,
        input_sanitization: :standard
      },
      strict: {
        encryption_enabled: true,
        audit_level: :comprehensive,
        access_control: :strict,
        input_sanitization: :strict
      },
      maximum: {
        encryption_enabled: true,
        audit_level: :maximum,
        access_control: :maximum,
        input_sanitization: :maximum
      }
    }.freeze

    # Field security classifications
    FIELD_SECURITY_CLASSIFICATIONS = {
      public: { encryption_required: false, access_level: :public, retention: nil },
      internal: { encryption_required: false, access_level: :internal, retention: 3.years },
      confidential: { encryption_required: true, access_level: :confidential, retention: 5.years },
      restricted: { encryption_required: true, access_level: :restricted, retention: 7.years },
      classified: { encryption_required: true, access_level: :classified, retention: 10.years }
    }.freeze

    # === MODULE METHODS ===

    # Extend base class with security features
    def self.extended(base)
      base.class_eval do
        # Include security associations
        include_security_associations

        # Include security validations
        include_security_validations

        # Include security callbacks
        include_security_callbacks

        # Include security scopes
        include_security_scopes

        # Initialize security configuration
        initialize_security_configuration
      end
    end

    private

    # Include security-related associations
    def include_security_associations
      # Security event tracking
      has_many :access_attempts, class_name: 'ModelAccessAttempt', dependent: :destroy if defined?(ModelAccessAttempt)
      has_many :security_events, class_name: 'ModelSecurityEvent', dependent: :destroy if defined?(ModelSecurityEvent)

      # Encryption metadata
      has_many :encryption_logs, class_name: 'ModelEncryptionLog', dependent: :destroy if defined?(ModelEncryptionLog)
    end

    # Include security validations
    def include_security_validations
      # Field-level security validations
      validate :validate_field_level_security
      validate :validate_data_classification_permissions
      validate :validate_encryption_requirements

      # Global security validations
      validates :security_level, inclusion: {
        in: SECURITY_LEVELS.keys.map(&:to_s)
      }, allow_nil: true if column_names.include?('security_level')

      validates :field_security_classifications, array_inclusion: {
        in: FIELD_SECURITY_CLASSIFICATIONS.keys.map(&:to_s)
      }, allow_nil: true if column_names.include?('field_security_classifications')
    end

    # Include security callbacks
    def include_security_callbacks
      # Security validation callbacks
      before_validation :sanitize_input_data, :validate_security_context
      before_save :encrypt_sensitive_fields, :update_security_metadata
      before_destroy :validate_deletion_permissions, :create_deletion_security_log

      # Security monitoring callbacks
      after_save :log_security_events, :update_access_timestamps
      after_commit :broadcast_security_events, :update_security_indexes
      after_rollback :handle_security_rollback
    end

    # Include security scopes
    def include_security_scopes
      scope :high_security, -> { where(security_level: [:strict, :maximum]) if column_names.include?('security_level') }
      scope :encrypted_data, -> { where(encryption_required: true) if column_names.include?('encryption_required') }
      scope :access_logged, -> { where(access_logging_enabled: true) if column_names.include?('access_logging_enabled') }
      scope :restricted_access, -> { where(access_level: [:restricted, :classified]) if column_names.include?('access_level') }
    end

    # Initialize security configuration
    def initialize_security_configuration
      @security_config = security_level_config
      @field_security_config = field_security_configurations
      @encryption_config = encryption_configuration
    end

    # === ENCRYPTION & SECURITY METHODS ===

    # Global encryption configuration for sensitive fields
    def encrypts(*fields)
      options = fields.extract_options!
      fields.each do |field|
        encrypt_field(field, options)
      end
    end

    # Configure field-level encryption
    def encrypt_field(field, options = {})
      return unless column_names.include?(field.to_s)

      # Configure Rails encryption
      super(field, options) if defined?(super)

      # Add blind index for encrypted fields
      blind_index(field) if options[:deterministic]
    end

    # Encrypt sensitive fields before storage
    def encrypt_sensitive_fields
      sensitive_fields.each do |field|
        next unless attribute_present?(field)

        encrypted_value = EncryptionService.encrypt_sensitive_data(
          send(field),
          classification: data_classification,
          field_name: field,
          security_level: security_level
        )

        send("#{field}=", encrypted_value)
      end
    end

    # Decrypt sensitive fields for access
    def decrypt_sensitive_fields
      sensitive_fields.each do |field|
        next unless attribute_present?(field)

        decrypted_value = EncryptionService.decrypt_sensitive_data(
          send(field),
          classification: data_classification,
          field_name: field,
          security_level: security_level
        )

        send("#{field}=", decrypted_value)
      end
    end

    # === PERMISSION METHODS ===

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

      # Check data classification permissions
      return false unless current_user_can_access_data_classification?

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

    # === SECURITY VALIDATION METHODS ===

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

    # Validate field-level security
    def validate_field_level_security
      return unless Current.user

      # Check each changed field for permissions
      changed.each do |field|
        unless current_user_can_modify_field?(field)
          errors.add(field, "cannot be modified - insufficient permissions")
        end
      end

      throw(:abort) if errors.any?
    end

    # Validate data classification permissions
    def validate_data_classification_permissions
      return unless data_classification.present? && Current.user

      unless current_user_can_access_data_classification?
        errors.add(:data_classification, "access denied for current user role")
        throw(:abort)
      end
    end

    # Validate encryption requirements
    def validate_encryption_requirements
      return unless encryption_required?

      sensitive_fields.each do |field|
        if attribute_present?(field) && !field_encrypted?(field)
          errors.add(field, "must be encrypted")
        end
      end

      throw(:abort) if errors.any?
    end

    # === SECURITY HELPER METHODS ===

    # Check if current user can access data classification
    def current_user_can_access_data_classification?
      return true unless Current.user && data_classification.present?

      classification = data_classification.to_sym
      user_clearance = Current.user.security_clearance&.to_sym || :public

      # Define clearance hierarchy
      clearance_levels = {
        public: 0,
        internal: 1,
        confidential: 2,
        restricted: 3,
        classified: 4
      }

      clearance_levels[user_clearance] >= clearance_levels[classification]
    end

    # Check if current user can modify a specific field
    def current_user_can_modify_field?(field)
      return true unless Current.user

      field_security = field_security_classification(field)
      return true if field_security == :public

      # Check field-specific permissions
      Current.user.can_modify_field?(self.class.name, field)
    end

    # Get security classification for a field
    def field_security_classification(field)
      field_config = @field_security_config[field.to_sym]
      return field_config[:classification] if field_config

      # Default classification based on field name patterns
      case field.to_s
      when /password|secret|token|key/
        :classified
      when /email|phone|address|ssn|social_security/
        :restricted
      when /name|description|notes/
        :confidential
      else
        :internal
      end
    end

    # Check if field is encrypted
    def field_encrypted?(field)
      encrypted_attributes.include?(field.to_s)
    end

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

    # === SECURITY LOGGING METHODS ===

    # Create comprehensive security log entry
    def create_security_log_entry(event:, details: {}, user: nil, context: {})
      return unless security_logging_enabled?

      security_events.create!(
        event: event,
        details: details,
        user: user || Current.user,
        ip_address: Current.ip_address,
        user_agent: Current.user_agent,
        session_id: Current.session_id,
        context: context,
        organization: organization || Current.organization,
        data_classification: data_classification,
        security_level: security_level,
        risk_score: calculate_security_risk_score(event, details),
        created_at: Time.current
      )
    end

    # Log security events after save
    def log_security_events
      return unless security_logging_enabled?

      # Log access events
      if access_logging_enabled?
        create_security_log_entry(
          event: :record_accessed,
          details: { operation: new_record? ? :create : :update }
        )
      end

      # Log sensitive data access
      if sensitive_data_operation?
        create_security_log_entry(
          event: :sensitive_data_accessed,
          details: { fields: sensitive_fields_modified }
        )
      end
    end

    # Update access timestamps
    def update_access_timestamps
      return unless column_names.include?('last_accessed_at')

      self.last_accessed_at = Time.current
      self.last_accessed_by = Current.user&.id
      self.last_accessed_ip = Current.ip_address
    end

    # Handle security rollback events
    def handle_security_rollback
      create_security_log_entry(
        event: :security_rollback,
        details: { reason: :transaction_rollback }
      )
    end

    # === SECURITY CONFIGURATION METHODS ===

    # Get security level configuration
    def security_level_config
      level = enterprise_module_config(:security)[:level] || :standard
      SECURITY_LEVELS[level.to_sym] || SECURITY_LEVELS[:standard]
    end

    # Get field security configurations
    def field_security_configurations
      return {} unless column_names.include?('field_security_classifications')

      field_security_classifications.each_with_object({}) do |field_config, config|
        field_name, classification = field_config.split(':')
        config[field_name.to_sym] = {
          classification: classification.to_sym,
          encryption_required: FIELD_SECURITY_CLASSIFICATIONS[classification.to_sym][:encryption_required]
        }
      end
    end

    # Get encryption configuration
    def encryption_configuration
      {
        algorithm: encryption_algorithm,
        key_rotation_days: key_rotation_period,
        blind_index_enabled: blind_index_enabled?,
        deterministic_encryption: deterministic_encryption_enabled?
      }
    end

    # === RISK ASSESSMENT METHODS ===

    # Calculate security risk score for events
    def calculate_security_risk_score(event, details)
      risk_factors = [
        event_risk_factor(event),
        data_sensitivity_risk_factor,
        user_risk_factor,
        timing_risk_factor,
        context_risk_factor(details)
      ]

      # Weighted average of risk factors
      weights = [0.3, 0.25, 0.2, 0.1, 0.15]
      risk_factors.zip(weights).sum { |factor, weight| factor * weight }
    end

    # Calculate risk factor for security event type
    def event_risk_factor(event)
      risk_levels = {
        record_accessed: 0.1,
        sensitive_data_accessed: 0.7,
        encryption_failed: 0.9,
        unauthorized_access: 1.0,
        security_violation: 1.0,
        security_rollback: 0.5
      }

      risk_levels[event.to_sym] || 0.3
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

    # Calculate risk factor based on context
    def context_risk_factor(details)
      risk_score = 0.0

      # High risk if sensitive fields are involved
      if details[:fields]&.any? { |field| field_security_classification(field) == :classified }
        risk_score += 0.4
      end

      # High risk for bulk operations
      if details[:bulk_operation]
        risk_score += 0.3
      end

      # High risk for system-level changes
      if details[:system_operation]
        risk_score += 0.2
      end

      risk_score
    end

    # === UTILITY METHODS ===

    # Check if security logging is enabled
    def security_logging_enabled?
      @security_config[:audit_level] != :minimal
    end

    # Check if access logging is enabled
    def access_logging_enabled?
      column_names.include?('access_logging_enabled') && access_logging_enabled?
    end

    # Get sensitive fields that were modified
    def sensitive_fields_modified
      sensitive_fields & changed
    end

    # Check if record requires encryption
    def requires_encryption?
      return true if sensitive_data_classification?

      # Check field-level encryption requirements
      sensitive_fields.any? { |field| attribute_present?(field) }
    end

    # Check if data classification indicates sensitive data
    def sensitive_data_classification?
      sensitive_classifications = [:sensitive_personal, :sensitive_financial,
                                 :sensitive_legal, :restricted_security]

      sensitive_classifications.include?(data_classification&.to_sym)
    end

    # Get list of sensitive fields requiring encryption
    def sensitive_fields
      @field_security_config.select { |_, config| config[:encryption_required] }.keys
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
      sensitive_fields.any? { |field| attribute_changed?(field) }
    end

    # === SECURITY METADATA METHODS ===

    # Update security metadata before save
    def update_security_metadata
      return unless column_names.include?('security_metadata')

      self.security_metadata = build_security_metadata
    end

    # Build comprehensive security metadata
    def build_security_metadata
      {
        encryption_status: encryption_status,
        access_level: security_level,
        field_classifications: @field_security_config,
        last_security_check: Time.current,
        security_config: @security_config
      }
    end

    # Get encryption status for the record
    def encryption_status
      {
        encryption_required: requires_encryption?,
        encrypted_fields: encrypted_fields_list,
        encryption_algorithm: encryption_algorithm,
        last_encryption_check: last_encryption_check,
        key_rotation_due: encryption_key_rotation_due?
      }
    end

    # Get list of encrypted fields
    def encrypted_fields_list
      encrypted_attributes.keys
    end

    # Get encryption algorithm
    def encryption_algorithm
      :aes256_gcm # Default algorithm
    end

    # Get last encryption check timestamp
    def last_encryption_check
      return unless column_names.include?('last_encryption_check')

      self[:last_encryption_check]
    end

    # Check if encryption key rotation is due
    def encryption_key_rotation_due?
      return false unless last_encryption_check

      key_rotation_days = @encryption_config[:key_rotation_days] || 90
      last_encryption_check < key_rotation_days.days.ago
    end

    # Check if blind index is enabled
    def blind_index_enabled?
      @encryption_config[:blind_index_enabled] || false
    end

    # Check if deterministic encryption is enabled
    def deterministic_encryption_enabled?
      @encryption_config[:deterministic_encryption] || false
    end

    # Get key rotation period
    def key_rotation_period
      case security_level&.to_sym
      when :maximum then 30
      when :strict then 60
      else 90
      end
    end

    # === INPUT SANITIZATION METHODS ===

    # Sanitize input data for security
    def sanitize_input_data
      # Sanitize string fields based on security level
      string_fields = attribute_names.select do |attr|
        column_for_attribute(attr)&.type == :string
      end

      string_fields.each do |field|
        next unless attribute_present?(field)

        sanitized_value = InputSanitizationService.sanitize(
          send(field),
          field_type: :string,
          max_length: column_for_attribute(field)&.limit,
          allow_html: field_allows_html?(field),
          security_level: @security_config[:input_sanitization]
        )

        send("#{field}=", sanitized_value)
      end

      # Validate data integrity
      validate_data_integrity
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

    # Validate data integrity for the record
    def validate_data_integrity
      # Check referential integrity
      validate_referential_integrity

      # Check business rule compliance
      validate_business_rules

      # Check data consistency
      validate_data_consistency
    end

    # === DELETION SECURITY METHODS ===

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

    # Create deletion security log
    def create_deletion_security_log
      return unless security_logging_enabled?

      create_security_log_entry(
        event: :record_deletion,
        details: {
          deletion_reason: deletion_reason,
          cascade_effects: cascade_deletion_effects,
          compliance_check: deletion_compliance_check
        }
      )
    end

    # === BROADCASTING METHODS ===

    # Broadcast security events
    def broadcast_security_events
      return unless real_time_security_updates_enabled?

      # Broadcast security violations
      if security_violation_detected?
        broadcast_security_violation
      end

      # Broadcast access events
      if access_logging_enabled?
        broadcast_access_event
      end
    end

    # Check if real-time security updates are enabled
    def real_time_security_updates_enabled?
      @security_config[:access_control] == :strict
    end

    # Check if security violation was detected
    def security_violation_detected?
      errors.any? { |error| error.attribute == :base && error.message.include?('permission') }
    end

    # Broadcast security violation
    def broadcast_security_violation
      # Implementation for broadcasting security violations
      SecurityViolationBroadcaster.broadcast(
        model: self.class.name,
        record_id: id,
        violation_type: :unauthorized_access,
        user: Current.user,
        timestamp: Time.current
      )
    end

    # Broadcast access event
    def broadcast_access_event
      # Implementation for broadcasting access events
      AccessEventBroadcaster.broadcast(
        model: self.class.name,
        record_id: id,
        event_type: :record_accessed,
        user: Current.user,
        timestamp: Time.current
      )
    end
  end
end