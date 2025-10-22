# =============================================================================
# XRP Transaction Model - Immutable Data Entity with Service Delegation
# =============================================================================
# This model represents the core data structure for XRP transactions, adhering
# to Clean Architecture principles by delegating all business logic to
# specialized service objects, ensuring high cohesion and low coupling.

class XrpTransaction < ApplicationRecord
  belongs_to :source_wallet, class_name: 'XrpWallet', optional: true
  belongs_to :destination_wallet, class_name: 'XrpWallet', optional: true
  belongs_to :order, optional: true
  belongs_to :user

  # Transaction types for comprehensive audit trail
  enum transaction_type: {
    incoming_payment: 0,     # Payment received
    outgoing_payment: 1,     # Payment sent
    exchange: 2,            # Currency exchange
    refund: 3,              # Refund transaction
    fee_payment: 4,         # Fee deduction
    staking_reward: 5,      # Staking rewards
    liquidity_provision: 6,  # Liquidity pool contribution
    internal_transfer: 7    # Internal wallet transfer
  }

  # Transaction status with detailed state tracking
  enum status: {
    pending: 0,                    # Awaiting submission
    submitted: 1,                  # Submitted to ledger
    pending_confirmation: 2,       # Awaiting confirmations
    confirmed: 3,                  # Confirmed on ledger
    failed: 4,                     # Transaction failed
    cancelled: 5,                  # Cancelled by user
    expired: 6,                    # Expired due to timeout
    disputed: 7,                   # Under dispute investigation
    quarantined: 8                 # Flagged for security review
  }

  # Validation rules with formal verification
  validates :amount_xrp, presence: true, numericality: { greater_than: 0 }
  validates :destination_address, presence: true
  validates :transaction_hash, uniqueness: true, allow_nil: true
  validates :fee_xrp, numericality: { greater_than_or_equal_to: 0 }
  validates :ledger_version, numericality: { greater_than: 0 }, allow_nil: true

  before_validation :calculate_transaction_fee, on: :create
  after_create :setup_monitoring_jobs
  after_update :notify_transaction_status_change

  # Delegate business logic to service objects
  delegate :calculate_fee, to: :fee_calculation_service, prefix: true
  delegate :monitor_confirmations, :confirm_transaction, to: :confirmation_service
  delegate :check_compliance, to: :compliance_service, prefix: true

  # Public interface methods for external interaction
  def monitor_confirmations
    confirmation_service.monitor_confirmations(self)
  end

  def confirm_transaction!
    confirmation_service.confirm_transaction(self)
  end

  def cancel_transaction!(reason = nil)
    cancellation_service.cancel_transaction(self, reason)
  end

  def calculate_transaction_fee
    result = fee_calculation_service.calculate_fee(self)
    self.fee_xrp = result.value! if result.success?
  end

  def transaction_analytics
    {
      compliance_flags: compliance_service_check_compliance,
      risk_score: ComplianceService.calculate_risk_score(compliance_service_check_compliance)
    }
  end

  def confirmations_expired?
    return false unless pending_confirmation?
    last_checked_at && last_checked_at < 24.hours.ago
  end

  def cancellable?
    [ :pending, :submitted ].include?(status.to_sym)
  end

  private

  # Service object instances for delegation
  def fee_calculation_service
    @fee_calculation_service ||= FeeCalculationService.new
  end

  def confirmation_service
    @confirmation_service ||= TransactionConfirmationService.new
  end

  def compliance_service
    @compliance_service ||= ComplianceService.new
  end

  def cancellation_service
    @cancellation_service ||= TransactionCancellationService.new
  end

  # Setup asynchronous monitoring jobs
  def setup_monitoring_jobs
    # Monitor transaction confirmations
    MonitorXrpConfirmationsJob.perform_later(id)

    # Monitor for stuck transactions
    MonitorStuckTransactionsJob.perform_later(id)

    # Monitor network conditions
    MonitorNetworkConditionsJob.perform_later(id)
  end

  # Notify relevant parties of status changes
  def notify_transaction_status_change
    return unless saved_change_to_status?

    # Send real-time notifications
    NotificationService.notify_transaction_status_change(self)

    # Update order status if applicable
    update_order_status if order

    # Record in audit trail
    record_audit_event
  end

  # Update associated order status
  def update_order_status
    return unless order

    case status.to_sym
    when :confirmed
      order.update!(payment_status: :paid) if transaction_type_incoming_payment?
    when :failed
      order.update!(payment_status: :failed)
    end
  end

  # Record transaction event in audit trail
  def record_audit_event
    AuditTrail.record(
      entity_type: 'XrpTransaction',
      entity_id: id,
      action: "status_changed_to_#{status}",
      user: user,
      metadata: {
        amount_xrp: amount_xrp,
        transaction_hash: transaction_hash,
        previous_status: status_previously_was
      }
    )
  end

  # Increment monitoring failure count for alerting
  def increment_monitoring_failure_count
    self.monitoring_failures ||= 0
    self.monitoring_failures += 1

    # Alert if too many failures
    if monitoring_failures >= 10
      AlertService.xrp_monitoring_failure(self)
    end
  end
end