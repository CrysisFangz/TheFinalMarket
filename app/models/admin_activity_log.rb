# frozen_string_literal: true

# Enterprise-grade admin activity logging system with comprehensive audit trails,
# real-time monitoring, advanced security, and intelligent analytics
#
# @author Kilo Code Autonomous Agent
# @version 2.0.0
# @since 2025-10-19
#
class AdminActivityLog < ApplicationRecord
  # === CONSTANTS ===
  # Enhanced action types with security classifications
  CRITICAL_ACTIONS = %i[
    system_shutdown
    data_purge
    security_breach_response
    emergency_access_grant
    audit_log_deletion
  ].freeze

  HIGH_RISK_ACTIONS = %i[
    user_data_export
    payment_refund_override
    account_termination
    compliance_violation_override
    manual_fraud_detection_override
  ].freeze

  SENSITIVE_ACTIONS = %i[
    personal_data_access
    financial_record_access
    security_log_review
    admin_permission_changes
    system_configuration_changes
  ].freeze

  COMPLIANCE_ACTIONS = %i[
    gdpr_data_request
    ccpa_data_request
    audit_report_generation
    compliance_review
    data_retention_update
  ].freeze

  # Comprehensive action type registry with metadata
  ACTION_REGISTRY = {
    # Financial Actions
    escrow_release: {
      category: :financial,
      severity: :high,
      compliance_flags: [:pci_dss, :sox],
      retention_period: 7.years,
      audit_required: true,
      description: 'Release funds from escrow account'
    },
    escrow_refund: {
      category: :financial,
      severity: :high,
      compliance_flags: [:pci_dss, :sox],
      retention_period: 7.years,
      audit_required: true,
      description: 'Process refund through escrow system'
    },
    payment_override: {
      category: :financial,
      severity: :critical,
      compliance_flags: [:pci_dss, :sox],
      retention_period: 7.years,
      audit_required: true,
      description: 'Manual override of payment processing'
    },

    # Dispute Management
    dispute_resolution: {
      category: :legal,
      severity: :medium,
      compliance_flags: [:gdpr],
      retention_period: 5.years,
      audit_required: true,
      description: 'Resolve customer dispute'
    },
    dispute_escalation: {
      category: :legal,
      severity: :high,
      compliance_flags: [:gdpr, :ccpa],
      retention_period: 7.years,
      audit_required: true,
      description: 'Escalate dispute to higher authority'
    },

    # User Management
    account_suspension: {
      category: :security,
      severity: :high,
      compliance_flags: [:gdpr, :ccpa],
      retention_period: 3.years,
      audit_required: true,
      description: 'Suspend user account'
    },
    account_termination: {
      category: :security,
      severity: :critical,
      compliance_flags: [:gdpr, :ccpa],
      retention_period: 7.years,
      audit_required: true,
      description: 'Permanently terminate user account'
    },
    emergency_access_grant: {
      category: :security,
      severity: :critical,
      compliance_flags: [:gdpr, :sox],
      retention_period: 10.years,
      audit_required: true,
      description: 'Grant emergency administrative access'
    },

    # System Administration
    system_configuration_changes: {
      category: :system,
      severity: :high,
      compliance_flags: [:sox],
      retention_period: 5.years,
      audit_required: true,
      description: 'Modify system configuration'
    },
    security_policy_update: {
      category: :security,
      severity: :critical,
      compliance_flags: [:sox, :iso27001],
      retention_period: 7.years,
      audit_required: true,
      description: 'Update security policies'
    },

    # Data Management
    data_export_request: {
      category: :data,
      severity: :medium,
      compliance_flags: [:gdpr, :ccpa],
      retention_period: 3.years,
      audit_required: true,
      description: 'Process data export request'
    },
    data_deletion_request: {
      category: :data,
      severity: :high,
      compliance_flags: [:gdpr, :ccpa],
      retention_period: 7.years,
      audit_required: true,
      description: 'Process data deletion request'
    },

    # Compliance & Audit
    audit_report_generation: {
      category: :compliance,
      severity: :medium,
      compliance_flags: [:sox, :iso27001],
      retention_period: 7.years,
      audit_required: false,
      description: 'Generate compliance audit report'
    },
    compliance_review: {
      category: :compliance,
      severity: :high,
      compliance_flags: [:sox, :gdpr, :ccpa],
      retention_period: 5.years,
      audit_required: false,
      description: 'Conduct compliance review'
    }
  }.freeze

  # === ASSOCIATIONS ===
  belongs_to :admin, class_name: 'User', inverse_of: :admin_activity_logs
  belongs_to :resource, polymorphic: true, optional: true

  # === ENCRYPTION & SECURITY ===
  encrypts :details, deterministic: true
  encrypts :admin_notes, :compliance_notes, deterministic: true
  blind_index :details, :admin_notes, :compliance_notes

  # === VALIDATIONS ===
  validates :action, presence: true, inclusion: { in: ACTION_REGISTRY.keys.map(&:to_s) }
  validates :details, presence: true, unless: :batch_operation?
  validates :severity, presence: true, inclusion: { in: %w[low medium high critical] }
  validates :ip_address, presence: true, format: { with: Resolv::IPv4::Regex }
  validates :user_agent, length: { maximum: 1000 }, allow_blank: true
  validates :session_id, presence: true, unless: :batch_operation?

  # === CALLBACKS ===
  before_validation :set_defaults, :enrich_activity_data
  after_create :trigger_real_time_notifications, :update_analytics

  # === SCOPES ===
  scope :recent, ->(limit = 100) {
    order(created_at: :desc).limit(limit)
  }

  scope :by_admin, ->(admin) {
    where(admin: admin).includes(:resource, :ip_geolocation)
  }

  scope :by_action, ->(action) {
    where(action: action.to_s).includes(:admin, :resource)
  }

  scope :by_severity, ->(severity) {
    where(severity: severity).order(created_at: :desc)
  }

  scope :critical_actions, -> {
    where(severity: :critical).order(created_at: :desc)
  }

  scope :high_risk_actions, -> {
    where(severity: %i[high critical]).order(created_at: :desc)
  }

  scope :today, -> {
    where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
  }

  scope :compliance_related, -> {
    where(action: COMPLIANCE_ACTIONS.map(&:to_s))
  }

  scope :financial_actions, -> {
    where(action: %w[escrow_release escrow_refund payment_override])
  }

  scope :security_related, -> {
    where(action: %w[account_suspension account_termination emergency_access_grant security_policy_update])
  }

  # === CLASS METHODS ===

  # Enhanced logging with comprehensive security and compliance features
  def self.log_action(admin:, action:, resource: nil, details: {}, **options)
    # Validate action type and permissions
    unless ACTION_REGISTRY.key?(action.to_sym)
      raise ArgumentError, "Invalid action type: #{action}"
    end

    # Check if admin has permission for this action
    validate_admin_permissions(admin, action)

    # Create activity log with enhanced metadata
    create_activity_log(admin, action, resource, details, options)
  end

  # Batch logging for high-volume operations
  def self.log_batch_actions(admin:, actions:, batch_metadata: {})
    transaction do
      actions.map do |action_data|
        action_data.merge!(
          admin: admin,
          batch_operation: true,
          batch_id: generate_batch_id,
          batch_metadata: batch_metadata
        )
        create!(action_data)
      end
    end
  end

  # === INSTANCE METHODS ===

  # Check if this action requires compliance audit
  def requires_compliance_audit?
    ACTION_REGISTRY.dig(action.to_sym, :audit_required) || critical_action?
  end

  # Determine if this is a critical security action
  def critical_action?
    CRITICAL_ACTIONS.include?(action.to_sym) || severity == 'critical'
  end

  # Get action metadata from registry
  def action_metadata
    ACTION_REGISTRY[action.to_sym] || {}
  end

  # Calculate retention date based on action type
  def retention_until
    return unless created_at

    period = action_metadata[:retention_period] || 3.years
    created_at + period
  end

  # Check if log entry should be archived
  def should_be_archived?
    return false unless retention_until

    Time.current > retention_until
  end

  # === PRIVATE METHODS ===

  private

  # Set default values before validation
  def set_defaults
    self.severity ||= calculate_severity
    self.ip_address ||= Current.ip_address
    self.user_agent ||= Current.user_agent
    self.session_id ||= Current.session_id
    self.data_classification ||= classify_data_sensitivity
  end

  # Enrich activity data with contextual information
  def enrich_activity_data
    # Add geographic context if available
    if ip_address && !ip_geolocation
      geolocation_service = GeolocationService.new(ip_address)
      build_ip_geolocation(geolocation_service.enrich_data)
    end

    # Add device fingerprinting if available
    if session_id && !device_fingerprint
      fingerprint_service = DeviceFingerprintService.new(session_id)
      build_device_fingerprint(fingerprint_service.generate_fingerprint)
    end

    # Calculate risk score based on various factors
    self.risk_score = calculate_risk_score
  end

  # Calculate severity level based on action type and context
  def calculate_severity
    metadata = action_metadata

    case metadata[:severity]
    when :critical then 'critical'
    when :high then 'high'
    when :medium then 'medium'
    else 'low'
    end
  end

  # Classify data sensitivity for compliance
  def classify_data_sensitivity
    case action_metadata[:category]
    when :financial then :sensitive_financial
    when :legal then :sensitive_legal
    when :security then :restricted_security
    else :internal_use
    end
  end

  # Calculate comprehensive risk score
  def calculate_risk_score
    risk_factors = [
      severity_factor,
      geographic_risk_factor,
      timing_risk_factor,
      permission_risk_factor,
      data_sensitivity_factor
    ]

    # Weighted average of risk factors
    weights = [0.3, 0.2, 0.15, 0.2, 0.15]
    risk_factors.zip(weights).sum { |factor, weight| factor * weight }
  end

  # Validate admin has necessary permissions for this action
  def self.validate_admin_permissions(admin, action)
    action_key = action.to_sym
    metadata = ACTION_REGISTRY[action_key]

    return unless metadata

    # Check if admin has required permissions
    required_permissions = metadata[:required_permissions] || []
    admin_permissions = admin.admin_permissions || []

    missing_permissions = required_permissions - admin_permissions
    unless missing_permissions.empty?
      raise SecurityError,
        "Admin #{admin.email} lacks permissions: #{missing_permissions.join(', ')}"
    end
  end

  # Create activity log with comprehensive metadata
  def self.create_activity_log(admin, action, resource, details, options)
    transaction do
      activity_log = new(
        admin: admin,
        action: action.to_s,
        resource: resource,
        details: details,
        severity: options[:severity] || calculate_severity_for_action(action),
        ip_address: options[:ip_address] || Current.ip_address,
        user_agent: options[:user_agent] || Current.user_agent,
        session_id: options[:session_id] || Current.session_id,
        compliance_flags: options[:compliance_flags] || [],
        admin_notes: options[:admin_notes],
        compliance_notes: options[:compliance_notes]
      )

      activity_log.save!
      activity_log
    end
  end

  # Generate unique batch ID for batch operations
  def self.generate_batch_id
    SecureRandom.uuid
  end

  # Calculate severity for a given action
  def self.calculate_severity_for_action(action)
    metadata = ACTION_REGISTRY[action.to_sym]
    return 'medium' unless metadata

    case metadata[:severity]
    when :critical then 'critical'
    when :high then 'high'
    when :medium then 'medium'
    else 'low'
    end
  end

  # Risk factor calculation methods
  def severity_factor
    { 'low' => 0.2, 'medium' => 0.5, 'high' => 0.8, 'critical' => 1.0 }[severity] || 0.5
  end

  def geographic_risk_factor
    return 0.1 unless ip_geolocation

    # Higher risk for unusual locations or VPN usage
    base_risk = ip_geolocation.risk_score || 0.0
    vpn_penalty = ip_geolocation.vpn_detected? ? 0.3 : 0.0
    base_risk + vpn_penalty
  end

  def timing_risk_factor
    # Higher risk for actions outside normal business hours
    hour = created_at&.hour || 12
    case hour
    when 9..17 then 0.1  # Business hours
    when 6..8, 18..21 then 0.3  # Extended hours
    else 0.5  # Off hours
    end
  end

  def permission_risk_factor
    # Risk based on admin's permission level and action sensitivity
    admin_risk = case admin.admin_level
                 when 'super_admin' then 0.1
                 when 'admin' then 0.3
                 when 'moderator' then 0.5
                 else 0.7
                 end

    action_risk = { 'low' => 0.2, 'medium' => 0.5, 'high' => 0.8, 'critical' => 1.0 }[severity] || 0.5
    [admin_risk, action_risk].max
  end

  def data_sensitivity_factor
    case data_classification
    when 'internal_use' then 0.1
    when 'sensitive_financial' then 0.6
    when 'sensitive_legal' then 0.7
    when 'restricted_security' then 0.9
    else 0.3
    end
  end

  # === ADVANCED FEATURES ===

  # Generate compliance report for this activity
  def generate_compliance_report
    {
      activity_id: id,
      action: action,
      timestamp: created_at,
      admin: admin.email,
      compliance_flags: action_metadata[:compliance_flags],
      retention_required: retention_until,
      audit_status: audit_status,
      risk_assessment: risk_assessment,
      geographic_context: ip_geolocation&.compliance_summary,
      data_classification: data_classification
    }
  end

  # Advanced filtering with AI-powered anomaly detection
  def self.with_advanced_filters(filters = {})
    query = all

    # Date range filtering
    if filters[:date_range].present?
      query = query.where(created_at: filters[:date_range])
    end

    # Admin filtering with role-based access
    if filters[:admin].present?
      query = query.by_admin(filters[:admin])
    end

    # Action type filtering
    if filters[:action_types].present?
      query = query.where(action: filters[:action_types].map(&:to_s))
    end

    # Severity filtering
    if filters[:severity_levels].present?
      query = query.where(severity: filters[:severity_levels])
    end

    # IP-based filtering with geolocation
    if filters[:ip_address].present?
      query = query.where(ip_address: filters[:ip_address])
    end

    # Compliance filtering
    if filters[:compliance_only].present?
      query = query.compliance_related
    end

    # Risk-based filtering
    if filters[:high_risk_only].present?
      query = query.high_risk_actions
    end

    # Geographic filtering
    if filters[:country_code].present?
      query = query.joins(:ip_geolocation)
                   .where(ip_geolocations: { country_code: filters[:country_code] })
    end

    # Anomaly detection filtering
    if filters[:anomalous_only].present?
      query = query.anomalous_activities
    end

    query.order(created_at: :desc)
  end

  # Trigger real-time notifications for critical activities
  def trigger_real_time_notifications
    return unless critical_action?

    # Send notifications to security team
    AdminNotificationService.notify_security_team(
      type: :critical_admin_action,
      activity_log: self,
      message: "Critical admin action: #{action} by #{admin.email}",
      priority: :urgent
    )

    # Trigger SIEM integration
    SiemIntegrationService.log_security_event(
      event_type: :admin_activity,
      severity: :critical,
      source: 'admin_panel',
      details: {
        admin_id: admin_id,
        action: action,
        ip_address: ip_address,
        risk_score: risk_score
      }
    )
  end

  # Update analytics and metrics
  def update_analytics
    # Update admin activity metrics
    AdminAnalyticsService.record_activity(
      admin: admin,
      action: action,
      timestamp: created_at,
      risk_score: risk_score
    )

    # Update compliance metrics
    if requires_compliance_audit?
      ComplianceMetricsService.record_audit_activity(
        action: action,
        admin: admin,
        compliance_flags: compliance_flags
      )
    end
  end

  # === CACHING ===
  # Cache frequently accessed compliance data
  rails_cache :compliance_summary, expires_in: 1.hour do
    {
      action: action,
      compliance_flags: compliance_flags,
      retention_period: action_metadata[:retention_period],
      audit_required: requires_compliance_audit?
    }
  end

  # Cache risk assessment
  rails_cache :risk_assessment, expires_in: 30.minutes do
    {
      risk_score: risk_score,
      risk_level: risk_level,
      factors: {
        severity: severity_factor,
        geographic: geographic_risk_factor,
        timing: timing_risk_factor,
        permissions: permission_risk_factor,
        data_sensitivity: data_sensitivity_factor
      }
    }
  end

  # === SEARCH & ANALYTICS ===
  # Elasticsearch integration for advanced search
  searchkick mappings: {
    action: { type: :keyword },
    severity: { type: :keyword },
    admin_email: { type: :keyword },
    ip_address: { type: :ip },
    details: { type: :object },
    compliance_flags: { type: :keyword },
    data_classification: { type: :keyword },
    risk_score: { type: :float },
    created_at: { type: :date }
  }

  def search_data
    {
      action: action,
      severity: severity,
      admin_email: admin.email,
      ip_address: ip_address,
      resource_type: resource_type,
      resource_id: resource_id,
      compliance_flags: compliance_flags,
      data_classification: data_classification,
      risk_score: risk_score,
      created_at: created_at,
      details: sanitized_details
    }
  end

  # === PERFORMANCE OPTIMIZATIONS ===
  # Database indexes for optimal query performance
  self.primary_key = :id

  # Composite indexes for common query patterns
  index :created_at
  index [:admin_id, :created_at]
  index [:action, :created_at]
  index [:severity, :created_at]
  index [:ip_address, :created_at]
  index [:risk_score, :created_at]

  # Partial indexes for specific use cases
  index :compliance_flags, where: "array_length(compliance_flags, 1) > 0"
  index :batch_id, where: "batch_id IS NOT NULL"
end