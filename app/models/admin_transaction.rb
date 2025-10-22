# frozen_string_literal: true

# Enterprise-grade administrative transaction management system with
# multi-level approval workflows, comprehensive audit trails, and
# intelligent risk assessment capabilities
#
# @author Kilo Code Autonomous Agent
# @version 2.0.0
# @since 2025-10-19
#
# @example
#   # Create a sophisticated approval workflow
#   transaction = AdminTransaction.create_approval_workflow(
#     admin: current_admin,
#     approvable: order,
#     action: :escrow_release,
#     amount: 1500.00,
#     currency: 'USD',
#     urgency: :high,
#     compliance_requirements: [:pci_dss, :sox],
#     justification: detailed_business_case
#   )
#
#   # Multi-level approval process
#   transaction.request_approval_from_senior_admin
#   transaction.escalate_to_compliance_officer if transaction.high_risk?
#
class AdminTransaction < ApplicationRecord
  # === CONSTANTS ===

  # Enhanced transaction types with comprehensive metadata
  TRANSACTION_TYPES = {
    # Financial Transactions
    escrow_release: {
      category: :financial,
      risk_level: :high,
      compliance_flags: [:pci_dss, :sox],
      approval_levels: [:admin, :senior_admin, :finance_manager],
      max_amount: 50_000,
      requires_justification: true,
      auto_approve_threshold: 1_000,
      description: 'Release funds from escrow account'
    },

    escrow_refund: {
      category: :financial,
      risk_level: :high,
      compliance_flags: [:pci_dss, :sox],
      approval_levels: [:admin, :senior_admin, :risk_manager],
      max_amount: 25_000,
      requires_justification: true,
      auto_approve_threshold: 500,
      description: 'Process refund through escrow system'
    },

    payment_override: {
      category: :financial,
      risk_level: :critical,
      compliance_flags: [:pci_dss, :sox, :audit_required],
      approval_levels: [:senior_admin, :finance_director, :compliance_officer],
      max_amount: 100_000,
      requires_justification: true,
      auto_approve_threshold: nil, # Never auto-approve
      description: 'Manual override of payment processing'
    },

    # Dispute Management
    dispute_resolution: {
      category: :legal,
      risk_level: :medium,
      compliance_flags: [:gdpr],
      approval_levels: [:admin, :legal_counsel],
      max_amount: nil, # Based on dispute value
      requires_justification: true,
      auto_approve_threshold: nil,
      description: 'Resolve customer dispute with settlement'
    },

    dispute_escalation: {
      category: :legal,
      risk_level: :high,
      compliance_flags: [:gdpr, :ccpa],
      approval_levels: [:admin, :senior_admin, :legal_director],
      max_amount: nil,
      requires_justification: true,
      auto_approve_threshold: nil,
      description: 'Escalate dispute to higher authority'
    },

    # User Management
    account_suspension: {
      category: :security,
      risk_level: :medium,
      compliance_flags: [:gdpr, :ccpa],
      approval_levels: [:admin, :security_manager],
      max_amount: nil,
      requires_justification: true,
      auto_approve_threshold: nil,
      description: 'Suspend user account with cause'
    },

    account_termination: {
      category: :security,
      risk_level: :high,
      compliance_flags: [:gdpr, :ccpa, :audit_required],
      approval_levels: [:admin, :senior_admin, :legal_counsel],
      max_amount: nil,
      requires_justification: true,
      auto_approve_threshold: nil,
      description: 'Permanently terminate user account'
    },

    # System Administration
    emergency_access_grant: {
      category: :security,
      risk_level: :critical,
      compliance_flags: [:sox, :iso27001, :audit_required],
      approval_levels: [:senior_admin, :security_director, :compliance_officer],
      max_amount: nil,
      requires_justification: true,
      auto_approve_threshold: nil,
      description: 'Grant emergency administrative access'
    },

    system_configuration_change: {
      category: :system,
      risk_level: :high,
      compliance_flags: [:sox, :audit_required],
      approval_levels: [:admin, :senior_admin, :system_administrator],
      max_amount: nil,
      requires_justification: true,
      auto_approve_threshold: nil,
      description: 'Modify critical system configuration'
    },

    # Data Management
    data_export_request: {
      category: :data,
      risk_level: :medium,
      compliance_flags: [:gdpr, :ccpa],
      approval_levels: [:admin, :data_protection_officer],
      max_amount: nil,
      requires_justification: true,
      auto_approve_threshold: nil,
      description: 'Process large data export request'
    },

    data_deletion_request: {
      category: :data,
      risk_level: :high,
      compliance_flags: [:gdpr, :ccpa, :audit_required],
      approval_levels: [:admin, :senior_admin, :data_protection_officer],
      max_amount: nil,
      requires_justification: true,
      auto_approve_threshold: nil,
      description: 'Process data deletion request'
    }
  }.freeze

  # Approval workflow states
  WORKFLOW_STATES = {
    draft: 'draft',
    pending_approval: 'pending_approval',
    under_review: 'under_review',
    approved: 'approved',
    rejected: 'rejected',
    cancelled: 'cancelled',
    escalated: 'escalated',
    auto_approved: 'auto_approved'
  }.freeze

  # Urgency levels
  URGENCY_LEVELS = {
    low: { max_processing_hours: 72, auto_escalate_hours: 48 },
    medium: { max_processing_hours: 24, auto_escalate_hours: 12 },
    high: { max_processing_hours: 4, auto_escalate_hours: 2 },
    critical: { max_processing_hours: 1, auto_escalate_hours: 0.5 }
  }.freeze

  # === ASSOCIATIONS ===
  belongs_to :admin, class_name: 'User', inverse_of: :admin_transactions
  belongs_to :approvable, polymorphic: true, optional: true

  # Multi-level approval workflow associations
  belongs_to :requested_by, class_name: 'User', optional: true
  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :reviewed_by, class_name: 'User', optional: true

  # Hierarchical approval structure
  belongs_to :parent_transaction, class_name: 'AdminTransaction', optional: true
  has_many :child_transactions, class_name: 'AdminTransaction',
           foreign_key: :parent_transaction_id, dependent: :restrict_with_exception

  # Audit trail and compliance associations
  belongs_to :session, class_name: 'UserSession', optional: true
  belongs_to :ip_geolocation, class_name: 'GeolocationEvent', optional: true
  belongs_to :device_fingerprint, class_name: 'DeviceFingerprint', optional: true

  # Approval workflow tracking
  has_many :approval_steps, class_name: 'AdminTransactionApproval',
           dependent: :destroy, inverse_of: :admin_transaction
  has_many :approval_history, through: :approval_steps, source: :user

  # === ENCRYPTION & SECURITY ===
  encrypts :reason, :justification, :internal_notes, deterministic: true
  encrypts :financial_data, :sensitive_metadata, deterministic: true
  blind_index :reason, :justification, :financial_data

  # === ENUMS ===
  enum :action, TRANSACTION_TYPES.keys.index_by(&:to_s).transform_values(&:to_s)
  enum :status, WORKFLOW_STATES
  enum :urgency, URGENCY_LEVELS.keys.index_by(&:to_s).transform_values(&:to_s)

  # === VALIDATIONS ===
  validates :action, presence: true, inclusion: { in: TRANSACTION_TYPES.keys.map(&:to_s) }
  validates :reason, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :justification, presence: true, if: :requires_justification?
  validates :status, presence: true, inclusion: { in: WORKFLOW_STATES.values }
  validates :urgency, presence: true, inclusion: { in: URGENCY_LEVELS.keys.map(&:to_s) }
  validates :amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :currency, inclusion: { in: Money::Currency.all.map(&:iso_code) }, allow_nil: true

  # Compliance validations
  validate :amount_within_limits, if: :amount_present?
  validate :admin_has_approval_authority
  validate :compliance_requirements_met
  validate :business_hours_validation, unless: :emergency_action?

  # === CALLBACKS ===
  before_validation :set_defaults, :enrich_transaction_data
  after_create :initialize_approval_workflow, :trigger_notifications
  after_update :process_workflow_transitions, :update_compliance_status
  after_create :schedule_urgency_monitoring, if: :urgent_action?

  # === SCOPES ===
  scope :recent, ->(limit = 100) { order(created_at: :desc).limit(limit) }
  scope :by_admin, ->(admin) { where(admin: admin) }
  scope :by_action, ->(action) { where(action: action) }
  scope :pending_approval, -> { where(status: :pending_approval) }
  scope :approved, -> { where(status: :approved) }
  scope :rejected, -> { where(status: :rejected) }
  scope :auto_approved, -> { where(status: :auto_approved) }
  scope :escalated, -> { where(status: :escalated) }
  scope :urgent, -> { where(urgency: %w[high critical]) }
  scope :overdue, -> { where('escalation_deadline < ?', Time.current) }
  scope :high_risk, -> { where(risk_score: 0.7..1.0) }
  scope :financial, -> { where(category: :financial) }
  scope :security_related, -> { where(category: :security) }
  scope :compliance_required, -> { where(compliance_audit_required: true) }

  # === CLASS METHODS ===

  # Create sophisticated approval workflow
  def self.create_approval_workflow(admin:, approvable: nil, action:, **options)
    transaction do
      # Validate transaction parameters
      validate_transaction_parameters(admin, action, options)

      # Create transaction with enhanced metadata
      admin_transaction = new(
        admin: admin,
        requested_by: options[:requested_by] || admin,
        approvable: approvable,
        action: action.to_s,
        reason: options[:reason],
        justification: options[:justification],
        amount: options[:amount],
        currency: options[:currency] || 'USD',
        urgency: options[:urgency] || :medium,
        financial_data: options[:financial_data],
        sensitive_metadata: options[:sensitive_metadata],
        compliance_flags: options[:compliance_flags] || [],
        internal_notes: options[:internal_notes]
      )

      admin_transaction.save!
      admin_transaction.initialize_approval_workflow
      admin_transaction
    end
  end

  # Advanced filtering with intelligent risk assessment
  def self.with_advanced_filters(filters = {})
    query = all.includes(:admin, :approvable, :approval_steps)

    # Status filtering
    if filters[:status].present?
      query = query.where(status: filters[:status])
    end

    # Admin filtering
    if filters[:admin].present?
      query = query.where(admin: filters[:admin])
    end

    # Action type filtering
    if filters[:action_types].present?
      query = query.where(action: filters[:action_types])
    end

    # Amount range filtering
    if filters[:amount_range].present?
      min_amount, max_amount = filters[:amount_range]
      query = query.where(amount: min_amount..max_amount)
    end

    # Urgency filtering
    if filters[:urgency_levels].present?
      query = query.where(urgency: filters[:urgency_levels])
    end

    # Risk score filtering
    if filters[:risk_range].present?
      query = query.where(risk_score: filters[:risk_range])
    end

    # Date range filtering
    if filters[:date_range].present?
      query = query.where(created_at: filters[:date_range])
    end

    # Compliance filtering
    if filters[:compliance_only].present?
      query = query.where(compliance_audit_required: true)
    end

    # Overdue filtering
    if filters[:overdue_only].present?
      query = query.overdue
    end

    query.order(created_at: :desc)
  end

  # === INSTANCE METHODS ===

  # Initialize multi-level approval workflow
  def initialize_approval_workflow
    transaction_type = TRANSACTION_TYPES[action.to_sym]
    return unless transaction_type

    # Create approval steps for each required level
    transaction_type[:approval_levels].each_with_index do |level, index|
      approval_steps.create!(
        approver_level: level,
        approver_role: approver_role_for_level(level),
        sequence_order: index + 1,
        status: index.zero? ? :pending : :not_started,
        due_date: calculate_due_date_for_step(index + 1)
      )
    end

    # Set initial workflow state
    update!(status: :pending_approval)
  end

  # Process approval from specific approver
  def process_approval(approver:, decision:, comments: nil)
    transaction do
      # Validate approver has authority
      validate_approver_authority(approver)

      # Find current approval step
      current_step = current_approval_step
      return unless current_step

      # Process the decision
      if decision == :approve
        approve_step(current_step, approver, comments)
      elsif decision == :reject
        reject_step(current_step, approver, comments)
      elsif decision == :escalate
        escalate_step(current_step, approver, comments)
      end
    end
  end

  # Check if transaction requires justification
  def requires_justification?
    TRANSACTION_TYPES.dig(action.to_sym, :requires_justification) || false
  end

  # Determine if this is an emergency action
  def emergency_action?
    urgency == 'critical' || action.to_sym == :emergency_access_grant
  end

  # Calculate comprehensive risk score
  def calculate_risk_score
    risk_factors = [
      action_risk_factor,
      amount_risk_factor,
      admin_risk_factor,
      timing_risk_factor,
      complexity_risk_factor
    ]

    # Weighted average with dynamic weighting
    weights = [0.3, 0.25, 0.2, 0.15, 0.1]
    risk_factors.zip(weights).sum { |factor, weight| factor * weight }
  end

  # Check if transaction is high risk
  def high_risk?
    risk_score >= 0.7 || critical_action? || emergency_action?
  end

  # Check if transaction is critical
  def critical_action?
    TRANSACTION_TYPES.dig(action.to_sym, :risk_level) == :critical
  end

  # Get transaction metadata
  def transaction_metadata
    TRANSACTION_TYPES[action.to_sym] || {}
  end

  # === PRIVATE METHODS ===

  private

  # Set default values before validation
  def set_defaults
    self.status ||= :draft
    self.urgency ||= :medium
    self.ip_address ||= Current.ip_address
    self.session_id ||= Current.session_id
    self.risk_score ||= calculate_risk_score
    self.escalation_deadline ||= calculate_escalation_deadline
  end

  # Enrich transaction data with contextual information
  def enrich_transaction_data
    # Add geolocation context
    if ip_address && !ip_geolocation
      geolocation_service = GeolocationService.new(ip_address)
      build_ip_geolocation(geolocation_service.enrich_data)
    end

    # Add device fingerprinting
    if session_id && !device_fingerprint
      fingerprint_service = DeviceFingerprintService.new(session_id)
      build_device_fingerprint(fingerprint_service.generate_fingerprint)
    end

    # Classify data sensitivity
    self.data_classification ||= classify_data_sensitivity
  end

  # Validate transaction parameters before creation
  def self.validate_transaction_parameters(admin, action, options)
    transaction_type = TRANSACTION_TYPES[action.to_sym]
    raise ArgumentError, "Invalid action type: #{action}" unless transaction_type

    # Validate admin permissions
    unless admin.has_approval_authority?(action)
      raise SecurityError, "Admin lacks authority for action: #{action}"
    end

    # Validate amount limits
    if options[:amount] && transaction_type[:max_amount]
      if options[:amount] > transaction_type[:max_amount]
        raise ValidationError, "Amount exceeds maximum limit for #{action}"
      end
    end

    # Validate justification requirement
    if transaction_type[:requires_justification] && !options[:justification].present?
      raise ValidationError, "Justification required for #{action}"
    end
  end

  # Validate amount is within configured limits
  def amount_within_limits
    metadata = transaction_metadata
    return unless amount && metadata[:max_amount]

    if amount > metadata[:max_amount]
      errors.add(:amount, "exceeds maximum allowed for this transaction type")
    end
  end

  # Validate admin has approval authority
  def admin_has_approval_authority
    return if admin&.has_approval_authority?(action)

    errors.add(:admin, "does not have authority to approve this transaction type")
  end

  # Validate compliance requirements are met
  def compliance_requirements_met
    required_flags = transaction_metadata[:compliance_flags] || []
    return if required_flags.empty?

    missing_flags = required_flags - (compliance_flags || [])
    return if missing_flags.empty?

    errors.add(:compliance_flags, "Missing required flags: #{missing_flags.join(', ')}")
  end

  # Validate business hours for non-emergency actions
  def business_hours_validation
    return unless created_at

    hour = created_at.hour
    unless hour.between?(9, 17) || hour.between?(6, 8) && urgency == 'high'
      errors.add(:created_at, "Transaction created outside business hours")
    end
  end

  # === WORKFLOW METHODS ===

  # Get current approval step
  def current_approval_step
    approval_steps.where(status: :pending).order(:sequence_order).first
  end

  # Approve current step
  def approve_step(step, approver, comments)
    step.update!(
      status: :approved,
      approved_by: approver,
      approved_at: Time.current,
      comments: comments
    )

    # Move to next step or complete workflow
    if next_step = next_approval_step(step)
      next_step.update!(status: :pending)
      update!(status: :under_review)
    else
      complete_workflow(approver, comments)
    end
  end

  # Reject current step
  def reject_step(step, approver, comments)
    step.update!(
      status: :rejected,
      approved_by: approver,
      approved_at: Time.current,
      comments: comments
    )

    update!(status: :rejected)
    notify_rejection(approver, comments)
  end

  # Escalate current step
  def escalate_step(step, approver, comments)
    step.update!(
      status: :escalated,
      approved_by: approver,
      approved_at: Time.current,
      comments: comments
    )

    update!(status: :escalated)
    notify_escalation(approver, comments)
  end

  # Complete approval workflow
  def complete_workflow(final_approver, comments)
    update!(
      status: :approved,
      approved_by: final_approver,
      approved_at: Time.current,
      final_comments: comments
    )

    execute_transaction
    notify_approval(final_approver, comments)
  end

  # Execute the approved transaction
  def execute_transaction
    case action.to_sym
    when :escrow_release
      execute_escrow_release
    when :escrow_refund
      execute_escrow_refund
    when :dispute_resolution
      execute_dispute_resolution
    when :account_suspension
      execute_account_suspension
    else
      execute_generic_action
    end
  end

  # === RISK ASSESSMENT METHODS ===

  # Calculate risk factor based on action type
  def action_risk_factor
    case transaction_metadata[:risk_level]
    when :low then 0.2
    when :medium then 0.5
    when :high then 0.8
    when :critical then 1.0
    else 0.3
    end
  end

  # Calculate risk factor based on amount
  def amount_risk_factor
    return 0.1 unless amount

    metadata = transaction_metadata
    max_amount = metadata[:max_amount] || 100_000

    # Risk increases with amount as percentage of maximum
    amount_ratio = amount.to_f / max_amount
    [amount_ratio, 1.0].min * 0.8
  end

  # Calculate risk factor based on admin's authority level
  def admin_risk_factor
    case admin.admin_level
    when 'super_admin' then 0.1
    when 'senior_admin' then 0.3
    when 'admin' then 0.5
    when 'moderator' then 0.7
    else 0.9
    end
  end

  # Calculate risk factor based on timing
  def timing_risk_factor
    hour = created_at&.hour || 12

    case hour
    when 9..17 then 0.1  # Business hours - low risk
    when 6..8, 18..21 then 0.3  # Extended hours - medium risk
    else 0.6  # Off hours - high risk
    end
  end

  # Calculate risk factor based on transaction complexity
  def complexity_risk_factor
    factors = [
      approval_steps.count > 3 ? 0.3 : 0.1,
      amount.present? ? 0.2 : 0.0,
      approvable.present? ? 0.1 : 0.0,
      emergency_action? ? 0.4 : 0.0
    ].sum

    [factors, 1.0].min
  end

  # === HELPER METHODS ===

  # Get appropriate approver role for approval level
  def approver_role_for_level(level)
    case level
    when :admin then :administrator
    when :senior_admin then :senior_administrator
    when :finance_manager then :finance_manager
    when :risk_manager then :risk_manager
    when :legal_counsel then :legal_counsel
    when :security_manager then :security_manager
    when :compliance_officer then :compliance_officer
    when :system_administrator then :system_administrator
    else :administrator
    end
  end

  # Calculate due date for approval step
  def calculate_due_date_for_step(step_number)
    urgency_config = URGENCY_LEVELS[urgency.to_sym]
    max_hours = urgency_config[:max_processing_hours] || 24

    # Distribute time across approval steps
    hours_per_step = max_hours.to_f / (approval_steps.count || 1)
    created_at + (hours_per_step * step_number).hours
  end

  # Calculate escalation deadline
  def calculate_escalation_deadline
    urgency_config = URGENCY_LEVELS[urgency.to_sym]
    auto_escalate_hours = urgency_config[:auto_escalate_hours] || 12

    created_at + auto_escalate_hours.hours
  end

  # Find next approval step
  def next_approval_step(current_step)
    approval_steps.where('sequence_order > ?', current_step.sequence_order)
                  .order(:sequence_order).first
  end

  # Classify data sensitivity
  def classify_data_sensitivity
    case transaction_metadata[:category]
    when :financial then :sensitive_financial
    when :legal then :sensitive_legal
    when :security then :restricted_security
    when :data then :sensitive_personal
    else :internal_use
    end
  end

  # Validate approver has authority for this transaction
  def validate_approver_authority(approver)
    current_step = current_approval_step
    return unless current_step

    unless approver.has_role?(current_step.approver_role) ||
           approver.admin_level == 'super_admin'
      raise SecurityError, "Approver lacks authority for this step"
    end
  end

  # === NOTIFICATION METHODS ===

  # Trigger notifications based on workflow events
  def trigger_notifications
    case status.to_sym
    when :pending_approval
      notify_pending_approval
    when :approved
      notify_approval(final_approver, final_comments)
    when :rejected
      notify_rejection(approved_by, final_comments)
    when :escalated
      notify_escalation(approved_by, final_comments)
    end
  end

  # Notify relevant parties of pending approval
  def notify_pending_approval
    AdminNotificationService.notify_approvers(
      transaction: self,
      message: "New transaction requires approval: #{action}",
      priority: urgency_level
    )
  end

  # Notify of approval completion
  def notify_approval(approver, comments)
    AdminNotificationService.notify_stakeholders(
      transaction: self,
      event: :approved,
      approver: approver,
      comments: comments
    )
  end

  # Notify of rejection
  def notify_rejection(approver, comments)
    AdminNotificationService.notify_stakeholders(
      transaction: self,
      event: :rejected,
      approver: approver,
      comments: comments
    )
  end

  # Notify of escalation
  def notify_escalation(approver, comments)
    AdminNotificationService.notify_senior_approvers(
      transaction: self,
      event: :escalated,
      approver: approver,
      comments: comments,
      priority: :urgent
    )
  end

  # === EXECUTION METHODS ===

  # Execute escrow release
  def execute_escrow_release
    EscrowService.release_funds(
      transaction: self,
      amount: amount,
      currency: currency,
      approver: approved_by,
      justification: justification
    )
  end

  # Execute escrow refund
  def execute_escrow_refund
    EscrowService.process_refund(
      transaction: self,
      amount: amount,
      currency: currency,
      approver: approved_by,
      justification: justification
    )
  end

  # Execute dispute resolution
  def execute_dispute_resolution
    DisputeResolutionService.execute_resolution(
      transaction: self,
      approver: approved_by,
      resolution_details: justification
    )
  end

  # Execute account suspension
  def execute_account_suspension
    UserManagementService.suspend_account(
      transaction: self,
      approver: approved_by,
      reason: reason,
      justification: justification
    )
  end

  # Execute generic action
  def execute_generic_action
    GenericTransactionService.execute(
      transaction: self,
      approver: approved_by,
      action_details: {
        action: action,
        reason: reason,
        justification: justification
      }
    )
  end

  # === BACKGROUND PROCESSING ===

  # Schedule urgency monitoring for time-sensitive transactions
  def schedule_urgency_monitoring
    return unless escalation_deadline

    AdminTransactionMonitoringJob.perform_at(
      escalation_deadline,
      id,
      :check_escalation
    )
  end

  # Process workflow state transitions
  def process_workflow_transitions
    # Auto-escalate if overdue
    if overdue? && status == 'pending_approval'
      escalate_overdue_transaction
    end

    # Auto-approve if within threshold and all criteria met
    if should_auto_approve?
      process_auto_approval
    end
  end

  # Check if transaction should be auto-approved
  def should_auto_approve?
    metadata = transaction_metadata
    threshold = metadata[:auto_approve_threshold]

    return false unless threshold && amount
    return false unless amount <= threshold

    # Check if all lower-level approvals are complete
    completed_steps = approval_steps.where(status: :approved).count
    total_steps = approval_steps.count

    completed_steps >= (total_steps * 0.7) # 70% approval threshold
  end

  # Process auto-approval
  def process_auto_approval
    update!(status: :auto_approved)

    AdminNotificationService.notify_auto_approval(
      transaction: self,
      message: "Transaction auto-approved based on policy: #{action}"
    )
  end

  # Escalate overdue transaction
  def escalate_overdue_transaction
    update!(status: :escalated)

    AdminNotificationService.notify_escalation(
      transaction: self,
      reason: :overdue,
      priority: :urgent
    )
  end

  # === CACHING & PERFORMANCE ===

  # Cache transaction metadata
  rails_cache :transaction_metadata, expires_in: 1.hour do
    {
      action: action,
      category: transaction_metadata[:category],
      risk_level: transaction_metadata[:risk_level],
      compliance_flags: compliance_flags,
      approval_levels: transaction_metadata[:approval_levels],
      max_amount: transaction_metadata[:max_amount]
    }
  end

  # Cache risk assessment
  rails_cache :risk_assessment, expires_in: 30.minutes do
    {
      risk_score: risk_score,
      risk_level: risk_level,
      factors: {
        action: action_risk_factor,
        amount: amount_risk_factor,
        admin: admin_risk_factor,
        timing: timing_risk_factor,
        complexity: complexity_risk_factor
      }
    }
  end

  # === SEARCH & ANALYTICS ===

  # Elasticsearch integration
  searchkick mappings: {
    action: { type: :keyword },
    status: { type: :keyword },
    urgency: { type: :keyword },
    admin_email: { type: :keyword },
    amount: { type: :float },
    currency: { type: :keyword },
    risk_score: { type: :float },
    created_at: { type: :date }
  }

  def search_data
    {
      action: action,
      status: status,
      urgency: urgency,
      admin_email: admin.email,
      amount: amount,
      currency: currency,
      risk_score: risk_score,
      compliance_flags: compliance_flags,
      data_classification: data_classification,
      created_at: created_at,
      justification: sanitized_justification
    }
  end

  # === PERFORMANCE OPTIMIZATIONS ===

  # Database indexes for optimal query performance
  self.primary_key = :id

  # Composite indexes for common query patterns
  index :created_at
  index [:admin_id, :created_at]
  index [:status, :created_at]
  index [:urgency, :created_at]
  index [:action, :status]
  index [:risk_score, :created_at]
  index [:escalation_deadline, :status]

  # Partial indexes for specific use cases
  index :amount, where: "amount IS NOT NULL"
  index :compliance_flags, where: "array_length(compliance_flags, 1) > 0"
  index :approved_by_id, where: "status = 'approved'"
end