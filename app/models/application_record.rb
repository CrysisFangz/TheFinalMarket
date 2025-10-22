# frozen_string_literal: true

# Clean, minimal ActiveRecord foundation with modular enterprise features
# through composition over inheritance
#
# @author Kilo Code Autonomous Agent
# @version 3.0.0
# @since 2025-10-22
#
# @example
#   class User < ApplicationRecord
#     # Include only the enterprise modules you need
#     include EnterpriseModules::SecurityModule
#     include EnterpriseModules::AuditModule
#     include EnterpriseModules::PerformanceModule
#
#     # Configure modules as needed
#     enterprise_modules do
#       security :strict
#       audit :comprehensive
#       performance :optimized
#     end
#   end
#
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # === MODULE INCLUSION SYSTEM ===

  # Enterprise modules registry - tracks which modules are included
  class_attribute :enterprise_modules_config, default: {}

  # Include enterprise modules based on configuration
  after_initialize :include_configured_modules

  # === BASIC ASSOCIATIONS ===

  # Multi-tenancy support (optional organization context)
  belongs_to :organization, optional: true if column_names.include?('organization_id')

  # === BASIC SCOPES ===

  # Basic scopes for common filtering patterns
  scope :recent, ->(timeframe = 24.hours) { where('created_at > ?', timeframe.ago) }
  scope :active, -> { where(active: true) if column_names.include?('active') }
  scope :for_organization, ->(org) { where(organization: org) if column_names.include?('organization_id') }

  # === MODULE CONFIGURATION ===

  # Configure enterprise modules for this model
  # @yield [config] Configuration DSL for enterprise modules
  def self.enterprise_modules(&block)
    config = EnterpriseModulesConfig.new
    config.instance_eval(&block) if block_given?

    self.enterprise_modules_config = config.to_hash
  end

  # === BASIC METHODS ===

  # Check if a specific enterprise module is included
  def has_enterprise_module?(module_name)
    self.class.enterprise_modules_config[module_name].present?
  end

  # Get configuration for a specific module
  def enterprise_module_config(module_name)
    self.class.enterprise_modules_config[module_name] || {}
  end

  private

  # Include configured enterprise modules
  def include_configured_modules
    return unless self.class.respond_to?(:enterprise_modules_config)

    self.class.enterprise_modules_config.each do |module_name, config|
      include_module_if_configured(module_name, config)
    end
  end

  # Include a specific module if configured
  def include_module_if_configured(module_name, config)
    return if config.blank?

    module_class_name = "EnterpriseModules::#{module_name.to_s.camelize}Module"
    module_class = module_class_name.safe_constantize

    return unless module_class

    # Extend with the module
    extend(module_class)

    # Initialize module-specific configuration
    initialize_module_config(module_name, config) if respond_to?(:initialize_module_config)
  end

  # === CONSTANTS (moved to separate constants file for better organization) ===

  # Core data classifications - extended by ComplianceModule if included
  CORE_DATA_CLASSIFICATIONS = {
    public_data: { level: 0, retention: nil, encryption_required: false },
    internal_use: { level: 1, retention: 3.years, encryption_required: false },
    sensitive_personal: { level: 2, retention: 5.years, encryption_required: true },
    sensitive_financial: { level: 3, retention: 7.years, encryption_required: true }
  }.freeze

  # === UTILITY METHODS ===

  # Enhanced find_or_create with optional enterprise features
  def self.find_or_create_with_enterprise_features(attributes, &block)
    transaction do
      existing_record = find_existing_with_context(attributes)

      if existing_record
        update_existing_enterprise_record(existing_record, attributes) if existing_record.respond_to?(:update_existing_enterprise_record)
        existing_record
      else
        create_with_enterprise_features(attributes, &block)
      end
    end
  end

  # Find existing record with context (can be enhanced by modules)
  def self.find_existing_with_context(attributes)
    find_by(attributes.slice(*primary_key_columns))
  end

  # Get primary key columns for finding existing records
  def self.primary_key_columns
    [primary_key].compact
  end

  # Update existing record with enterprise features (enhanced by modules)
  def self.update_existing_enterprise_record(record, attributes)
    record.assign_attributes(attributes)
    record.save if record.changed?
    record
  end

  # Create with enterprise features (enhanced by modules)
  def self.create_with_enterprise_features(attributes, &block)
    new(attributes, &block).tap(&:save)
  end

  # === MODULE PLACEHOLDER METHODS ===

  # These methods are placeholders that can be enhanced by including modules
  # They provide default behavior when modules are not included

  # Security-related methods (enhanced by SecurityModule)
  def current_user_has_permission?
    true # Default: no permission checking
  end

  def current_user_can_access_sensitive_data?
    true # Default: allow access to sensitive data
  end

  def current_user_can_modify_record?
    true # Default: allow modifications
  end

  def current_user_can_delete_record?
    true # Default: allow deletions
  end

  # Audit-related methods (enhanced by AuditModule)
  def audit_trail_enabled?
    false # Default: no audit trail
  end

  def create_audit_log_entry(*args)
    # Default: no-op
  end

  # Performance-related methods (enhanced by PerformanceModule)
  def performance_monitoring_enabled?
    false # Default: no performance monitoring
  end

  def record_performance_metrics(*args)
    # Default: no-op
  end

  # Compliance-related methods (enhanced by ComplianceModule)
  def compliance_required?
    false # Default: no compliance requirements
  end

  def check_retention_compliance
    # Default: no-op
  end

  # Search-related methods (enhanced by SearchModule)
  def search_enabled?
    false # Default: no search integration
  end

  def update_search_indexes
    # Default: no-op
  end

  # Notification-related methods (enhanced by NotificationModule)
  def notifications_enabled?
    false # Default: no notifications
  end

  def broadcast_changes
    # Default: no-op
  end

  # Caching-related methods (enhanced by CachingModule)
  def update_dependent_caches
    # Default: no-op
  end

  # Integration-related methods (enhanced by IntegrationModule)
  def external_integration_enabled?
    false # Default: no external integrations
  end

  def propagate_changes_to_external_systems
    # Default: no-op
  end

  # === DEFAULT INCLUDES FOR PERFORMANCE ===

  # Default associations to include for performance
  def default_includes
    # Override in subclasses to define default eager loading
    []
  end

  # Performance-specific associations to include
  def performance_includes
    # Override in subclasses for performance-optimized queries
    default_includes
  end

  # === BASIC FIELD CONFIGURATION ===

  # Get list of sensitive fields requiring encryption (enhanced by SecurityModule)
  def self.sensitive_fields
    # Override in subclasses to define sensitive fields
    []
  end

  # Check if organization context is required (enhanced by modules)
  def organization_required?
    # Override in subclasses
    false
  end

  # Check if operation involves sensitive data (enhanced by SecurityModule)
  def sensitive_data_operation?
    # Check if any sensitive fields are being modified
    sensitive_fields = self.class.sensitive_fields || []
    sensitive_fields.any? { |field| attribute_changed?(field) }
  end

  # === BASIC SNAPSHOT GENERATION ===

  # Generate basic snapshot for backup/audit
  def generate_comprehensive_snapshot
    {
      record_data: attributes.compact,
      associations: serialize_associations,
      metadata: build_basic_metadata,
      timestamp: Time.current
    }
  end

  # Serialize associated data for snapshot
  def serialize_associations
    # Implementation depends on specific associations
    # Override in subclasses for comprehensive serialization
    {}
  end

  # Build basic metadata for the record
  def build_basic_metadata
    {
      model_name: self.class.name,
      record_id: id,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  # === ERROR HANDLING ===

  # Basic error handling (enhanced by modules)
  def handle_enterprise_error(error, context = {})
    # Log basic error context
    Rails.logger.error "Enterprise Error in #{self.class.name}: #{error.message}"
    Rails.logger.error "Context: #{context.inspect}"

    # Re-raise for default Rails error handling
    raise error
  end

  # === MODULE REGISTRY ===

  # Enterprise modules configuration DSL
  class EnterpriseModulesConfig
    def initialize
      @config = {}
    end

    # Configure security module
    def security(level = :standard)
      @config[:security] = { level: level }
    end

    # Configure audit module
    def audit(level = :basic)
      @config[:audit] = { level: level }
    end

    # Configure performance module
    def performance(level = :standard)
      @config[:performance] = { level: level }
    end

    # Configure compliance module
    def compliance(level = :standard)
      @config[:compliance] = { level: level }
    end

    # Configure data quality module
    def data_quality(level = :standard)
      @config[:data_quality] = { level: level }
    end

    # Configure search module
    def search(level = :basic)
      @config[:search] = { level: level }
    end

    # Configure notification module
    def notification(level = :basic)
      @config[:notification] = { level: level }
    end

    # Configure caching module
    def caching(level = :standard)
      @config[:caching] = { level: level }
    end

    # Configure integration module
    def integration(level = :basic)
      @config[:integration] = { level: level }
    end

    # Convert to hash for storage
    def to_hash
      @config
    end
  end
end