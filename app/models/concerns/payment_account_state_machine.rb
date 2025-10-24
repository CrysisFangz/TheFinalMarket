# frozen_string_literal: true

# Payment Account State Machine
# Enterprise-grade state management with audit trails and validation
module PaymentAccountStateMachine
  extend ActiveSupport::Concern

  included do
    # State machine configuration
    state_machine :status, initial: :pending do
      # Pending state - initial account state
      state :pending do
        def activate!
          transition_to(:active, :activation_validated)
        end

        def suspend!
          transition_to(:suspended, :compliance_violation)
        end
      end

      # Active state - fully operational account
      state :active do
        def suspend!
          transition_to(:suspended, :risk_assessment)
        end

        def terminate!
          transition_to(:terminated, :account_closure)
        end

        def restrict!
          transition_to(:restricted, :compliance_action)
        end
      end

      # Suspended state - temporarily disabled
      state :suspended do
        def reactivate!
          transition_to(:active, :appeal_approved)
        end

        def terminate!
          transition_to(:terminated, :permanent_closure)
        end
      end

      # Restricted state - limited operations
      state :restricted do
        def lift_restrictions!
          transition_to(:active, :restrictions_lifted)
        end

        def suspend!
          transition_to(:suspended, :escalated_action)
        end
      end

      # Terminated state - permanently closed
      state :terminated do
        def reactivate!
          raise PaymentAccountError.new('Cannot reactivate terminated account', :invalid_transition)
        end
      end

      # Global transitions
      event :activate do
        transition [:pending, :suspended] => :active
      end

      event :suspend do
        transition [:pending, :active, :restricted] => :suspended
      end

      event :restrict do
        transition [:active] => :restricted
      end

      event :terminate do
        transition [:pending, :active, :suspended, :restricted] => :terminated
      end

      # State machine callbacks
      before_transition do |account, transition|
        account.validate_state_transition!(transition)
      end

      after_transition do |account, transition|
        account.record_state_transition(transition)
        account.broadcast_state_change(transition.to, transition.event)
      end
    end

    # Risk level state machine
    state_machine :risk_level, initial: :low do
      state :low, :medium, :high, :critical, :extreme

      event :escalate_risk do
        transition low: :medium, medium: :high, high: :critical, critical: :extreme
      end

      event :reduce_risk do
        transition extreme: :critical, critical: :high, high: :medium, medium: :low
      end

      after_transition do |account, transition|
        account.record_risk_level_change(transition)
      end
    end

    # Compliance status state machine
    state_machine :compliance_status, initial: :unverified do
      state :unverified, :pending, :verified, :failed, :expired

      event :verify do
        transition [:unverified, :pending] => :verified
      end

      event :fail_verification do
        transition [:unverified, :pending] => :failed
      end

      event :expire_verification do
        transition [:verified] => :expired
      end

      after_transition do |account, transition|
        account.record_compliance_status_change(transition)
      end
    end
  end

  # State transition validation
  def validate_state_transition!(transition)
    case transition.event
    when :activate
      validate_activation_transition(transition)
    when :suspend
      validate_suspension_transition(transition)
    when :terminate
      validate_termination_transition(transition)
    end
  end

  def validate_activation_transition(transition)
    return if pending?

    # Check if account can be reactivated
    if suspended? && suspension_reason == 'permanent'
      raise PaymentAccountError.new('Cannot activate permanently suspended account', :invalid_activation)
    end

    # Validate compliance requirements for activation
    unless compliance_requirements_met?
      raise PaymentAccountError.new('Compliance requirements not met for activation', :compliance_not_met)
    end
  end

  def validate_suspension_transition(transition)
    return if can_suspend?

    # Check for pending critical operations
    if has_pending_critical_operations?
      raise PaymentAccountError.new('Cannot suspend account with pending critical operations', :pending_operations)
    end
  end

  def validate_termination_transition(transition)
    return if can_terminate?

    # Check for active funds or obligations
    if has_active_obligations?
      raise PaymentAccountError.new('Cannot terminate account with active obligations', :active_obligations)
    end
  end

  # State validation helpers
  def can_suspend?
    %w[pending active restricted].include?(status) && !has_pending_critical_operations?
  end

  def can_terminate?
    %w[pending active suspended restricted].include?(status) && !has_active_obligations?
  end

  def compliance_requirements_met?
    compliance_status == 'verified' && kyc_status == 'verified'
  end

  def has_pending_critical_operations?
    payment_transactions.where(status: [:pending, :processing]).exists? ||
    escrow_holds.where(status: :active).exists?
  end

  def has_active_obligations?
    available_balance > Money.new(0) ||
    escrow_holds.where(status: :active).exists? ||
    bond_transactions.where(status: :active).exists?
  end

  # State transition recording
  def record_state_transition(transition)
    PaymentAccountStateTransition.create!(
      payment_account: self,
      from_status: transition.from,
      to_status: transition.to,
      event: transition.event.to_s,
      triggered_by: transition.args.first || 'system',
      transition_metadata: {
        timestamp: Time.current,
        user_id: Current.user&.id,
        request_id: Current.request_id,
        ip_address: Current.ip_address
      }
    )
  end

  def record_risk_level_change(transition)
    PaymentAccountRiskTransition.create!(
      payment_account: self,
      from_risk_level: transition.from,
      to_risk_level: transition.to,
      event: transition.event.to_s,
      risk_score: fraud_detection_score,
      transition_metadata: {
        timestamp: Time.current,
        assessment_version: '2.1.0'
      }
    )
  end

  def record_compliance_status_change(transition)
    PaymentAccountComplianceTransition.create!(
      payment_account: self,
      from_compliance_status: transition.from,
      to_compliance_status: transition.to,
      event: transition.event.to_s,
      compliance_score: compliance_score,
      transition_metadata: {
        timestamp: Time.current,
        validation_version: '3.2.0'
      }
    )
  end

  # State queries
  def active?
    status == 'active'
  end

  def suspended?
    status == 'suspended'
  end

  def terminated?
    status == 'terminated'
  end

  def restricted?
    status == 'restricted'
  end

  def pending?
    status == 'pending'
  end

  def operational?
    active? && !restricted?
  end

  def high_risk?
    %w[high critical extreme].include?(risk_level)
  end

  def compliant?
    compliance_status == 'verified'
  end

  def premium_verified?
    verification_level == 'premium'
  end

  def enhanced_verification?
    %w[enhanced premium].include?(verification_level)
  end
end