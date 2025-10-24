# frozen_string_literal: true

# Enterprise Payment Account Model
# Refactored for asymptotic optimality, systemic elegance, and unbounded scalability
# Implements CQRS, Event Sourcing, and Domain-Driven Design patterns
class PaymentAccount < ApplicationRecord
  include PaymentAccountStateMachine
  include PaymentAccountValidations
  include PaymentAccountCallbacks
  include PaymentAccountScopes
  include PaymentAccountSerialization

  # Core Associations
  belongs_to :user
  has_many :payment_transactions, foreign_key: :source_account_id
  has_many :target_transactions, class_name: 'PaymentTransaction', foreign_key: :target_account_id
  has_many :escrow_holds
  has_many :escrow_transactions, through: :escrow_holds
  has_many :bond_transactions
  has_many :fraud_assessments, class_name: 'PaymentFraudAssessment', dependent: :destroy
  has_many :compliance_records, class_name: 'PaymentComplianceRecord', dependent: :destroy
  has_many :blockchain_records, class_name: 'PaymentBlockchainRecord', dependent: :destroy
  has_many :audit_events, class_name: 'PaymentAuditEvent', dependent: :destroy

  # Polymorphic associations for different account types
  has_many :buyer_transactions, class_name: 'PaymentTransaction', foreign_key: :source_account_id
  has_many :seller_transactions, class_name: 'PaymentTransaction', foreign_key: :target_account_id

  # Enterprise Attributes with Zero-Trust Architecture
  attribute :status, :string, default: 'pending'
  attribute :account_type, :string, default: 'standard'
  attribute :risk_level, :string, default: 'low'
  attribute :compliance_status, :string, default: 'unverified'
  attribute :kyc_status, :string, default: 'unverified'
  attribute :verification_level, :string, default: 'basic'

  # Financial Attributes
  attribute :available_balance_cents, :integer, default: 0
  attribute :reserved_balance_cents, :integer, default: 0
  attribute :pending_balance_cents, :integer, default: 0
  attribute :daily_transaction_limit_cents, :integer, default: 10000000 # $100,000
  attribute :monthly_transaction_limit_cents, :integer, default: 100000000 # $1,000,000

  # Security and Fraud Detection Attributes
  attribute :fraud_detection_score, :decimal, default: 0.0
  attribute :compliance_score, :decimal, default: 0.0
  attribute :payment_velocity_score, :decimal, default: 0.0
  attribute :distributed_payment_id, :string
  attribute :blockchain_verification_hash, :string

  # Metadata and Audit Attributes
  attribute :activation_metadata, :json, default: {}
  attribute :suspension_metadata, :json, default: {}
  attribute :payment_method_metadata, :json, default: {}
  attribute :distributed_processing_metadata, :json, default: {}
  attribute :enterprise_audit_data, :json, default: {}
  attribute :global_compliance_data, :json, default: {}

  # Performance and Caching Attributes
  attribute :last_balance_calculation_at, :datetime
  attribute :last_risk_assessment_at, :datetime
  attribute :last_compliance_check_at, :datetime
  attribute :cache_version, :string

  # Dependency Injection for Domain Services
  def payment_account_service
    @payment_account_service ||= PaymentAccountService.new(self)
  end

  def payment_balance_calculator
    @payment_balance_calculator ||= PaymentBalanceCalculator.new
  end

  def payment_risk_assessor
    @payment_risk_assessor ||= PaymentRiskAssessor.new
  end

  def payment_compliance_validator
    @payment_compliance_validator ||= PaymentComplianceValidator.new
  end

  def payment_eligibility_validator
    @payment_eligibility_validator ||= PaymentEligibilityValidator.new
  end

  # Enterprise Business Methods with Reactive Architecture

  # Activate account with full audit trail and compliance validation
  def activate_account!(activation_params = {})
    with_transaction_rollback_protection do
      result = payment_account_service.activate_account(activation_params)

      unless result.success?
        raise PaymentAccountError.new("Account activation failed: #{result.message}", result.error_code)
      end

      broadcast_state_change(:activated, result.data)
      result.data
    end
  end

  # Suspend account with fraud detection and compliance workflows
  def suspend_account!(suspension_reason, admin_user_id = nil)
    with_transaction_rollback_protection do
      result = payment_account_service.suspend_account(suspension_reason, admin_user_id)

      unless result.success?
        raise PaymentAccountError.new("Account suspension failed: #{result.message}", result.error_code)
      end

      broadcast_state_change(:suspended, result.data)
      result.data
    end
  end

  # Update payment methods with comprehensive validation
  def update_payment_methods!(payment_methods_data)
    with_transaction_rollback_protection do
      result = payment_account_service.update_payment_methods(payment_methods_data)

      unless result.success?
        raise PaymentAccountError.new("Payment methods update failed: #{result.message}", result.error_code)
      end

      broadcast_state_change(:payment_methods_updated, result.data)
      result.data
    end
  end

  # Calculate available balance with high-performance caching
  def available_balance(force_refresh: false)
    payment_balance_calculator.calculate_available_balance(self)
  end

  # Assess current risk level with ML-powered fraud detection
  def assess_risk_level(context = {})
    result = payment_risk_assessor.assess_account_risk(self, context)

    unless result.success?
      Rails.logger.error("Risk assessment failed for account #{id}: #{result.message}")
      return nil
    end

    result.data
  end

  # Validate compliance status with multi-jurisdictional checks
  def validate_compliance!(context = {})
    result = payment_compliance_validator.validate_account(self, context)

    unless result.success?
      raise PaymentAccountError.new("Compliance validation failed: #{result.message}", :compliance_violation)
    end

    result.data
  end

  # Validate payment eligibility for orders
  def validate_payment_eligibility(order)
    result = payment_eligibility_validator.validate(self, order)

    unless result.success?
      raise PaymentAccountError.new("Payment eligibility validation failed: #{result.message}", :ineligible)
    end

    result.data
  end

  # Process payment with reactive architecture and circuit breakers
  def process_payment(payment_transaction, payment_params = {})
    CircuitBreaker.execute_with_fallback(:payment_processing) do
      ReactivePromise.new do |resolve, reject|
        begin
          # Validate payment eligibility
          validate_payment_eligibility(payment_transaction.order)

          # Execute payment processing command
          command = PaymentAccountCommands::ProcessPaymentCommand.new(
            payment_account_id: id,
            payment_transaction_id: payment_transaction.id,
            payment_params: payment_params,
            request_id: SecureRandom.uuid
          )

          result = command.execute

          if result.success?
            resolve.call(result)
          else
            reject.call(PaymentAccountError.new(result.message, result.error_code))
          end
        rescue => e
          reject.call(e)
        end
      end
    end
  end

  # Enterprise State Management with Event Sourcing

  def current_state
    @current_state ||= load_current_state
  end

  def apply_event(event)
    case event.event_type
    when 'PaymentAccountActivated'
      apply_activation_event(event)
    when 'PaymentAccountSuspended'
      apply_suspension_event(event)
    when 'PaymentMethodsUpdated'
      apply_payment_methods_event(event)
    when 'PaymentAccountRiskLevelChanged'
      apply_risk_level_event(event)
    else
      Rails.logger.warn("Unknown event type: #{event.event_type}")
    end

    @current_state = event
  end

  # Performance Monitoring and Observability

  def with_performance_monitoring(operation_name)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    begin
      yield
    ensure
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      duration = end_time - start_time

      # Record performance metrics
      record_performance_metric(operation_name, duration)

      # Alert if performance exceeds thresholds
      alert_if_slow_operation(operation_name, duration)
    end
  end

  def record_performance_metric(operation_name, duration)
    PerformanceMetric.create!(
      operation: operation_name,
      duration_seconds: duration,
      payment_account_id: id,
      metadata: {
        account_type: account_type,
        risk_level: risk_level,
        operation_context: operation_name
      }
    )
  end

  def alert_if_slow_operation(operation_name, duration)
    slow_thresholds = {
      balance_calculation: 0.1,    # 100ms
      risk_assessment: 0.5,        # 500ms
      compliance_check: 1.0,       # 1s
      payment_processing: 2.0      # 2s
    }

    threshold = slow_thresholds[operation_name.to_sym] || 1.0
    if duration > threshold
      PerformanceAlertJob.perform_async(
        id,
        operation_name,
        duration,
        threshold
      )
    end
  end

  # Distributed Processing Support

  def distributed_payment_id
    super || generate_distributed_id
  end

  def generate_distributed_id
    SecureRandom.uuid.tap do |uuid|
      update!(distributed_payment_id: uuid)
    end
  end

  # Blockchain Integration Support

  def blockchain_verification_hash
    super || generate_blockchain_hash
  end

  def generate_blockchain_hash
    Digest::SHA256.hexdigest("#{id}:#{created_at}:#{SecureRandom.hex(32)}").tap do |hash|
      update!(blockchain_verification_hash: hash)
    end
  end

  # Enterprise Security Features

  def encrypt_sensitive_data
    # Encrypt payment methods and sensitive metadata
    self.payment_methods = EncryptionService.encrypt(payment_methods) if payment_methods_changed?
    self.activation_metadata = EncryptionService.encrypt(activation_metadata) if activation_metadata_changed?
    self.suspension_metadata = EncryptionService.encrypt(suspension_metadata) if suspension_metadata_changed?
  end

  def decrypt_sensitive_data
    # Decrypt for business logic processing
    @decrypted_payment_methods ||= EncryptionService.decrypt(payment_methods) if payment_methods.present?
    @decrypted_activation_metadata ||= EncryptionService.decrypt(activation_metadata) if activation_metadata.present?
    @decrypted_suspension_metadata ||= EncryptionService.decrypt(suspension_metadata) if suspension_metadata.present?
  end

  # Audit Trail and Compliance

  def audit_trail
    @audit_trail ||= PaymentAuditTrail.new(self)
  end

  def compliance_report
    @compliance_report ||= PaymentComplianceReport.new(self)
  end

  # Reactive State Broadcasting

  def broadcast_state_change(state_type, event_data = nil)
    # Broadcast to WebSocket channels
    PaymentAccountChannel.broadcast_to(self, {
      type: 'state_changed',
      state_type: state_type,
      account_id: id,
      event_data: event_data,
      timestamp: Time.current
    })

    # Publish to event bus for projections
    EventPublisher.publish('payment_account.state_changes', {
      account_id: id,
      state_type: state_type,
      event_data: event_data,
      timestamp: Time.current
    })
  end

  # Error Handling and Resilience

  def with_transaction_rollback_protection
    ActiveRecord::Base.transaction(isolation: :serializable) do
      yield
    end
  rescue ActiveRecord::SerializationFailure => e
    # Handle serialization conflicts with exponential backoff
    retry_count ||= 0
    retry_count += 1

    if retry_count <= 3
      sleep_time = 0.1 * (2 ** (retry_count - 1))
      sleep(sleep_time)
      retry
    else
      raise PaymentAccountError.new("Transaction serialization failed after #{retry_count} retries", :serialization_failure)
    end
  rescue => e
    Rails.logger.error("Payment account operation failed: #{e.message}")
    raise PaymentAccountError.new("Operation failed: #{e.message}", :operation_failed)
  end

  # Private helper methods

  private

  def load_current_state
    # Load current state from event store
    events = EventStore.instance.load_events("payment_account_#{id}")
    events.last || PaymentAccountState.new(self)
  end

  def apply_activation_event(event)
    self.status = :active
    self.activated_at = event.occurred_at
    self.activation_metadata = event.activation_metadata
  end

  def apply_suspension_event(event)
    self.status = :suspended
    self.suspended_at = event.occurred_at
    self.suspension_metadata = event.suspension_metadata
  end

  def apply_payment_methods_event(event)
    self.payment_methods = event.payment_methods_data
    self.last_payment_method_update = event.occurred_at
    self.payment_method_metadata = event.update_metadata
  end

  def apply_risk_level_event(event)
    self.risk_level = event.new_risk_level
    self.last_risk_assessment_at = event.occurred_at
    self.risk_assessment_metadata = event.context
  end

  def generate_cache_version
    Digest::SHA256.hexdigest("#{id}:#{updated_at}:#{SecureRandom.hex(8)}")
  end
end

# Enterprise Payment Account Error Class
class PaymentAccountError < StandardError
  attr_reader :error_code, :context_data

  def initialize(message, error_code = nil, context_data = {})
    super(message)
    @error_code = error_code
    @context_data = context_data
  end

  def to_h
    {
      error: message,
      error_code: error_code,
      context: context_data,
      timestamp: Time.current
    }
  end
end
