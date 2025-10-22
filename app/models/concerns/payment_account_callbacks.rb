# frozen_string_literal: true

# Payment Account Callbacks
# Enterprise-grade lifecycle management with audit trails
module PaymentAccountCallbacks
  extend ActiveSupport::Concern

  included do
    # Before callbacks
    before_validation :set_default_values, on: :create
    before_validation :sanitize_input_data
    before_validation :encrypt_sensitive_data
    before_save :update_calculated_fields
    before_save :validate_business_rules

    # After callbacks
    after_create :trigger_creation_workflows
    after_update :trigger_update_workflows, if: :significant_changes?
    after_save :broadcast_account_changes
    after_save :update_search_indexes

    # Error handling callbacks
    after_rollback :handle_rollback_actions

    # Performance monitoring callbacks
    around_save :with_performance_monitoring
    around_update :with_performance_monitoring
  end

  private

  # Before validation callbacks

  def set_default_values
    self.status ||= 'pending'
    self.account_type ||= 'standard'
    self.risk_level ||= 'low'
    self.compliance_status ||= 'unverified'
    self.kyc_status ||= 'unverified'
    self.verification_level ||= 'basic'

    # Generate secure identifiers
    self.distributed_payment_id ||= generate_distributed_id
    self.blockchain_verification_hash ||= generate_blockchain_hash
    self.cache_version ||= generate_cache_version
  end

  def sanitize_input_data
    # Sanitize and normalize input data
    self.business_email = business_email&.downcase&.strip if business_email.present?
    self.merchant_name = merchant_name&.strip if merchant_name.present?

    # Sanitize payment methods
    if payment_methods.present?
      self.payment_methods = payment_methods.map do |method|
        sanitize_payment_method(method)
      end
    end

    # Sanitize metadata fields
    self.activation_metadata = sanitize_metadata(activation_metadata) if activation_metadata.present?
    self.suspension_metadata = sanitize_metadata(suspension_metadata) if suspension_metadata.present?
    self.payment_method_metadata = sanitize_metadata(payment_method_metadata) if payment_method_metadata.present?
  end

  def encrypt_sensitive_data
    # Encrypt sensitive data before saving
    if payment_methods_changed? && payment_methods.present?
      self.payment_methods = EncryptionService.encrypt(payment_methods)
    end

    if activation_metadata_changed? && activation_metadata.present?
      self.activation_metadata = EncryptionService.encrypt(activation_metadata)
    end

    if suspension_metadata_changed? && suspension_metadata.present?
      self.suspension_metadata = EncryptionService.encrypt(suspension_metadata)
    end
  end

  def update_calculated_fields
    # Update calculated balance fields
    self.available_balance_cents = calculate_available_balance_cents
    self.last_balance_calculation_at = Time.current if balance_fields_changed?

    # Update risk and compliance scores
    self.fraud_detection_score = calculate_current_fraud_score
    self.compliance_score = calculate_current_compliance_score
    self.payment_velocity_score = calculate_current_velocity_score

    # Update cache version
    self.cache_version = generate_cache_version if significant_changes?
  end

  def validate_business_rules
    # Validate business rules before save
    validate_balance_limits
    validate_risk_limits
    validate_compliance_requirements
  end

  # After callbacks

  def trigger_creation_workflows
    # Trigger async workflows for new accounts
    PaymentAccountCreationJob.perform_async(id)

    # Initialize risk assessment
    PaymentRiskAssessmentJob.perform_async(id)

    # Initialize compliance validation
    PaymentComplianceValidationJob.perform_async(id)

    # Set up monitoring
    PaymentAccountMonitoringJob.perform_async(id)

    # Create audit trail entry
    create_audit_trail_entry('account_created', 'Account created successfully')
  end

  def trigger_update_workflows
    # Trigger workflows based on what changed
    if status_changed?
      trigger_status_change_workflows
    end

    if risk_level_changed?
      trigger_risk_level_workflows
    end

    if compliance_status_changed?
      trigger_compliance_workflows
    end

    if payment_methods_changed?
      trigger_payment_method_workflows
    end

    # Create audit trail entry for significant changes
    create_audit_trail_entry('account_updated', 'Account updated with significant changes')
  end

  def broadcast_account_changes
    # Broadcast changes to real-time subscribers
    PaymentAccountChannel.broadcast_to(self, {
      type: 'account_updated',
      account_id: id,
      changes: saved_changes.keys,
      timestamp: Time.current
    })

    # Publish to event bus for projections
    EventPublisher.publish('payment_account.updates', {
      account_id: id,
      changes: saved_changes,
      timestamp: Time.current
    })
  end

  def update_search_indexes
    # Update search indexes for account
    PaymentAccountSearchIndexJob.perform_async(id)
  end

  # Error handling callbacks

  def handle_rollback_actions
    # Handle cleanup when transaction rolls back
    Rails.logger.warn("Payment account #{id} transaction rolled back")

    # Clean up any external resources
    cleanup_external_resources

    # Notify monitoring systems
    notify_rollback_to_monitoring
  end

  # Performance monitoring callbacks

  def with_performance_monitoring
    operation_name = "payment_account_#{new_record? ? 'create' : 'update'}"

    with_performance_monitoring(operation_name) do
      yield
    end
  end

  # Helper methods

  def sanitize_payment_method(method)
    return method unless method.is_a?(Hash)

    sanitized = method.deep_dup

    # Sanitize string fields
    sanitized.each do |key, value|
      if value.is_a?(String)
        sanitized[key] = value.strip
      end
    end

    # Remove potentially dangerous fields
    sanitized.delete(:debug_info)
    sanitized.delete(:internal_notes)

    sanitized
  end

  def sanitize_metadata(metadata)
    return metadata unless metadata.is_a?(Hash)

    sanitized = metadata.deep_dup

    # Remove sensitive or unnecessary metadata
    sanitized.delete(:debug_info)
    sanitized.delete(:internal_logs)
    sanitized.delete(:temporary_data)

    sanitized
  end

  def calculate_available_balance_cents
    # Calculate available balance from transactions
    completed_incoming = payment_transactions.where(status: :completed, transaction_type: :purchase).sum(:amount_cents)
    completed_outgoing = payment_transactions.where(status: :completed, transaction_type: :payout).sum(:amount_cents)

    completed_incoming - completed_outgoing
  end

  def balance_fields_changed?
    saved_changes.keys.intersect?(%w[available_balance_cents reserved_balance_cents pending_balance_cents])
  end

  def calculate_current_fraud_score
    # Calculate current fraud detection score
    fraud_service = FraudDetectionService.new
    fraud_service.calculate_account_score(self)
  end

  def calculate_current_compliance_score
    # Calculate current compliance score
    compliance_service = ComplianceService.new
    compliance_service.calculate_account_score(self)
  end

  def calculate_current_velocity_score
    # Calculate current payment velocity score
    velocity_service = PaymentVelocityService.new
    velocity_service.calculate_account_score(self)
  end

  def validate_balance_limits
    # Validate balance doesn't exceed limits
    max_balance = case account_type
                  when 'enterprise' then 100000000 # $1,000,000
                  when 'premium' then 10000000    # $100,000
                  else 1000000                    # $10,000
                  end

    if available_balance_cents > max_balance
      errors.add(:available_balance_cents, "exceeds maximum for #{account_type} accounts")
    end
  end

  def validate_risk_limits
    # Validate risk level is appropriate for account type
    risk_account_type_compatibility = {
      'standard' => %w[low medium],
      'premium' => %w[low medium high],
      'enterprise' => %w[low medium high critical]
    }

    allowed_risk_levels = risk_account_type_compatibility[account_type] || %w[low]
    unless allowed_risk_levels.include?(risk_level)
      errors.add(:risk_level, "not allowed for #{account_type} accounts")
    end
  end

  def validate_compliance_requirements
    # Validate compliance requirements based on account type
    compliance_requirements = {
      'standard' => 'basic',
      'premium' => 'verified',
      'enterprise' => 'verified'
    }

    required_compliance = compliance_requirements[account_type]
    if required_compliance && compliance_status != required_compliance
      errors.add(:compliance_status, "must be #{required_compliance} for #{account_type} accounts")
    end
  end

  def significant_changes?
    significant_fields = %w[
      status account_type risk_level compliance_status kyc_status
      verification_level payment_methods available_balance_cents
    ]

    (saved_changes.keys & significant_fields).any?
  end

  def trigger_status_change_workflows
    case status
    when 'active'
      PaymentAccountActivationJob.perform_async(id)
    when 'suspended'
      PaymentAccountSuspensionJob.perform_async(id)
    when 'terminated'
      PaymentAccountTerminationJob.perform_async(id)
    end
  end

  def trigger_risk_level_workflows
    case risk_level
    when 'high', 'critical', 'extreme'
      PaymentAccountHighRiskJob.perform_async(id)
    end
  end

  def trigger_compliance_workflows
    case compliance_status
    when 'verified'
      PaymentAccountComplianceVerifiedJob.perform_async(id)
    when 'failed'
      PaymentAccountComplianceFailedJob.perform_async(id)
    end
  end

  def trigger_payment_method_workflows
    PaymentAccountPaymentMethodsJob.perform_async(id)
  end

  def cleanup_external_resources
    # Clean up external integrations
    if square_account_id.present?
      SquareCleanupJob.perform_async(square_account_id)
    end

    # Clean up blockchain resources
    if blockchain_verification_hash.present?
      BlockchainCleanupJob.perform_async(id)
    end
  end

  def notify_rollback_to_monitoring
    # Notify monitoring systems of rollback
    MonitoringService.notify(
      event: 'payment_account_rollback',
      account_id: id,
      timestamp: Time.current,
      severity: :warning
    )
  end

  def create_audit_trail_entry(action, description)
    PaymentAuditEvent.create!(
      payment_account: self,
      action: action,
      description: description,
      performed_by: Current.user&.id || 'system',
      performed_at: Time.current,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent,
      metadata: {
        account_changes: saved_changes,
        request_id: Current.request_id
      }
    )
  end

  def generate_distributed_id
    SecureRandom.uuid
  end

  def generate_blockchain_hash
    Digest::SHA256.hexdigest("#{id}:#{created_at}:#{SecureRandom.hex(32)}")
  end

  def generate_cache_version
    Digest::SHA256.hexdigest("#{id}:#{updated_at}:#{SecureRandom.hex(8)}")
  end
end