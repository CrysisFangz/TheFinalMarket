# Enterprise-Grade Buyer Account Model
# Refactored for modularity, scalability, and performance.
# Core model focused on data persistence with delegated business logic.

class BuyerAccount < PaymentAccount
  include SquareAccount

  # Associations
  has_many :purchase_transactions, class_name: 'PaymentTransaction', foreign_key: 'source_account_id'
  has_many :payment_events, class_name: 'PaymentEvent', dependent: :destroy
  has_many :fraud_assessments, class_name: 'PaymentFraudAssessment', dependent: :destroy
  has_many :compliance_records, class_name: 'PaymentComplianceRecord', dependent: :destroy
  has_many :blockchain_records, class_name: 'PaymentBlockchainRecord', dependent: :destroy

  # Enums
  enum payment_status: {
    active: 'active',
    suspended: 'suspended',
    restricted: 'restricted',
    terminated: 'terminated',
    under_review: 'under_review',
    compliance_hold: 'compliance_hold'
  }, _prefix: :payment_status

  enum risk_level: {
    low: 'low',
    medium: 'medium',
    high: 'high',
    critical: 'critical',
    extreme: 'extreme'
  }, _prefix: :risk_level

  # Validations
  validates :payment_status, presence: true, inclusion: { in: payment_statuses.keys }
  validates :risk_level, presence: true, inclusion: { in: risk_levels.keys }

  # Attributes
  attribute :distributed_payment_id, :string
  attribute :fraud_detection_score, :decimal, default: 0.0
  attribute :compliance_score, :decimal, default: 0.0
  attribute :payment_velocity_score, :decimal, default: 0.0
  attribute :distributed_processing_metadata, :json, default: {}
  attribute :ai_fraud_insights, :json, default: {}
  attribute :global_compliance_data, :json, default: {}
  attribute :blockchain_verification_metadata, :json, default: {}
  attribute :enterprise_audit_data, :json, default: {}

  # Callbacks
  before_validation :set_default_status, on: :create
  after_create :trigger_async_jobs
  after_update :broadcast_state_changes, if: :saved_change_to_payment_status?

  # Dependency Injection for Services
  def payment_processing_service
    @payment_processing_service ||= PaymentProcessingService.new
  end

  def fraud_detection_service
    @fraud_detection_service ||= FraudDetectionService.new
  end

  def compliance_service
    @compliance_service ||= ComplianceService.new
  end

  def blockchain_verification_service
    @blockchain_verification_service ||= BlockchainVerificationService.new
  end

  # Delegated Methods
  def process_purchase_reactive(order)
    payment_processing_service.process_purchase(self, order)
  end

  def process_refund_reactive(order)
    payment_processing_service.process_refund(self, order)
  end

  def execute_ai_fraud_assessment(context = {})
    fraud_detection_service.execute_assessment(self, context)
  end

  def monitor_payment_behavior_patterns(context = {})
    fraud_detection_service.monitor_behavior(self, context)
  end

  def validate_payment_compliance(context = {})
    compliance_service.validate(self, context)
  end

  def execute_blockchain_payment_verification(context = {})
    blockchain_verification_service.verify(self, context)
  end

  def available_balance_with_precision
    Rails.cache.fetch("balance_#{id}", expires_in: 5.minutes) do
      PaymentBalanceCalculator.new.calculate_available_balance(self)
    end
  end

  def calculate_payment_velocity_score
    PaymentVelocityCalculator.new.calculate_current_velocity_score(self)
  end

  def assess_current_risk_level
    PaymentRiskAssessor.new.assess_current_risk_level(self)
  end

  def validate_payment_eligibility(order)
    PaymentEligibilityValidator.new.validate(self, order)
  end

  # Event Sourcing
  def broadcast_state_changes
    PaymentEventPublisher.new.publish(PaymentStateChangedEvent.new(account: self))
  end

  private

  def set_default_status
    self.payment_status ||= :active
    self.risk_level ||= :low
  end

  def trigger_async_jobs
    GlobalPaymentSynchronizationJob.perform_async(id, :create)
    DistributedPaymentProcessingJob.perform_async(id)
    AIFraudAssessmentJob.perform_async(id)
    GlobalPaymentComplianceValidationJob.perform_async(id)
  end

  def stripe_account_type
    'customer'
  end
end