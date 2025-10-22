# frozen_string_literal: true

require_relative 'commands'
require_relative 'event_store'
require_relative 'read_model'
require_relative 'risk_calculator'

# Reactive bond transaction command processor with circuit breakers and CQRS
class BondTransactionCommandProcessor
  include ServiceResultHelper

  def self.execute_processing(command)
    CircuitBreaker.execute_with_fallback(:bond_transaction_processing) do
      ReactivePromise.new do |resolve, reject|
        Concurrent::Future.execute do
          begin
            result = process_bond_transaction_safely(command)
            resolve.call(result)
          rescue => e
            reject.call(e)
          end
        end
      end
    end
  rescue => e
    failure_result("Bond transaction processing failed: #{e.message}")
  end

  def self.execute_verification(command)
    CircuitBreaker.execute_with_fallback(:bond_transaction_verification) do
      ReactivePromise.new do |resolve, reject|
        Concurrent::Future.execute do
          begin
            result = verify_bond_transaction_safely(command)
            resolve.call(result)
          rescue => e
            reject.call(e)
          end
        end
      end
    end
  rescue => e
    failure_result("Bond transaction verification failed: #{e.message}")
  end

  private

  def self.process_bond_transaction_safely(command)
    command.validate!

    # Execute parallel transaction validation with zero-trust perimeter
    validation_results = execute_parallel_transaction_validation(command)

    # Check for validation failures
    if validation_results.any? { |result| result[:status] == :failure }
      raise BondTransactionValidationError, "Transaction validation failed"
    end

    # Create transaction through event sourcing
    ActiveRecord::Base.transaction(isolation: :serializable) do
      transaction_record = create_transaction_record(command)
      event = build_transaction_created_event(transaction_record, command)
      BondTransactionEventStore.append_event(event)
      publish_transaction_creation_events(event, command)
    end

    success_result(transaction_record, 'Bond transaction created successfully')
  end

  def self.verify_bond_transaction_safely(command)
    command.validate!

    # Load current state through CQRS read model
    transaction_record = BondTransaction.find(command.transaction_id)
    read_model = BondTransactionReadModel.find_by(id: command.transaction_id)

    # Execute verification based on type
    verification_result = execute_transaction_verification(command, transaction_record, read_model)

    unless verification_result.success?
      raise BondTransactionVerificationError, "Transaction verification failed: #{verification_result.error}"
    end

    # Update state through event sourcing
    ActiveRecord::Base.transaction(isolation: :serializable) do
      event = build_transaction_verified_event(transaction_record, verification_result, command)
      BondTransactionEventStore.append_event(event)
      update_read_model_projection(read_model, event)
      publish_transaction_verification_events(event, command)
    end

    success_result(transaction_record, 'Bond transaction verified successfully')
  end

  def self.execute_parallel_transaction_validation(command)
    # Parallel validation for transaction processing with enhanced security
    validations = [
      -> { validate_bond_eligibility(command) },
      -> { validate_amount_constraints(command) },
      -> { validate_financial_risk(command) },
      -> { validate_compliance_requirements(command) },
      -> { validate_payment_method(command) },
      -> { validate_zero_trust_perimeter(command) }
    ]

    ParallelExecutionService.execute(validations)
  end

  def self.validate_bond_eligibility(command)
    bond = Bond.find(command.bond_id)

    unless bond.active? || bond.pending?
      return failure_result("Bond is not in valid state for transaction")
    end

    success_result(bond, "Bond eligibility validated")
  rescue ActiveRecord::RecordNotFound
    failure_result("Bond not found")
  end

  def self.validate_amount_constraints(command)
    # Validate amount constraints based on transaction type
    max_amounts = {
      payment: Money.new(10_000_00),     # $10,000
      refund: Money.new(5_000_00),      # $5,000
      forfeiture: Money.new(10_000_00),  # $10,000
      adjustment: Money.new(100_00),     # $100
      reversal: Money.new(5_000_00),    # $5,000
      correction: Money.new(50_00)       # $50
    }

    amount = Money.new(command.amount_cents, 'USD')
    max_amount = max_amounts[command.transaction_type] || Money.new(1_000_00)

    unless amount <= max_amount
      return failure_result("Transaction amount exceeds maximum allowed: #{max_amount.format}")
    end

    success_result(amount, "Amount constraints validated")
  end

  def self.validate_financial_risk(command)
    # Calculate financial risk for transaction with ML enhancement
    temp_transaction_state = BondTransactionState.new(
      nil, command.bond_id, command.payment_transaction_id,
      TransactionType.from_string(command.transaction_type.to_s),
      command.amount_cents, TransactionStatus.from_string('pending'),
      ProcessingStage.from_string('initialized'), nil, Time.current, nil, nil,
      nil, nil, nil, 0, command.metadata, 1, nil, nil, nil, nil, Time.current
    )

    risk_score = temp_transaction_state.calculate_financial_risk

    if risk_score > 0.8
      return failure_result("Excessive financial risk: #{risk_score}")
    end

    success_result({ risk_score: risk_score }, "Financial risk assessment completed")
  end

  def self.validate_compliance_requirements(command)
    # Validate compliance requirements based on amount and type
    amount = Money.new(command.amount_cents, 'USD')

    compliance_service = ComplianceValidationService.new

    compliance_result = compliance_service.validate_transaction(
      amount_cents: command.amount_cents,
      transaction_type: command.transaction_type,
      metadata: command.metadata
    )

    unless compliance_result.valid?
      return failure_result("Compliance validation failed: #{compliance_result.errors.join(', ')}")
    end

    success_result(compliance_result, "Compliance requirements validated")
  end

  def self.validate_payment_method(command)
    return success_result(nil, "No payment method validation needed") unless command.payment_transaction_id

    payment_transaction = PaymentTransaction.find(command.payment_transaction_id)

    unless payment_transaction.completed?
      return failure_result("Payment transaction is not completed")
    end

    unless payment_transaction.amount_cents == command.amount_cents
      return failure_result("Payment transaction amount mismatch")
    end

    success_result(payment_transaction, "Payment method validated")
  rescue ActiveRecord::RecordNotFound
    failure_result("Payment transaction not found")
  end

  def self.validate_zero_trust_perimeter(command)
    # Zero-trust validation perimeter
    zero_trust_validator = ZeroTrustValidator.new

    validation_result = zero_trust_validator.validate_command(
      command: command,
      context: {
        timestamp: command.timestamp,
        request_id: command.request_id,
        correlation_id: command.correlation_id
      }
    )

    unless validation_result.authorized?
      return failure_result("Zero-trust validation failed: #{validation_result.errors.join(', ')}")
    end

    success_result(validation_result, "Zero-trust perimeter validated")
  end

  def self.create_transaction_record(command)
    BondTransaction.create!(
      bond_id: command.bond_id,
      payment_transaction_id: command.payment_transaction_id,
      transaction_type: command.transaction_type.to_s,
      amount_cents: command.amount_cents,
      status: :pending,
      processing_stage: :initialized,
      metadata: command.metadata.merge(
        created_by_command: true,
        command_request_id: command.request_id,
        priority_level: command.priority_level,
        correlation_id: command.correlation_id,
        causation_id: command.causation_id
      ),
      created_at: command.timestamp,
      correlation_id: command.correlation_id,
      causation_id: command.causation_id
    )
  end

  def self.build_transaction_created_event(transaction_record, command)
    {
      event_id: SecureRandom.uuid,
      event_type: 'BondTransactionCreated',
      aggregate_id: transaction_record.id,
      aggregate_type: 'BondTransaction',
      event_data: {
        bond_id: transaction_record.bond_id,
        payment_transaction_id: transaction_record.payment_transaction_id,
        transaction_type: transaction_record.transaction_type,
        amount_cents: transaction_record.amount_cents,
        status: transaction_record.status,
        processing_stage: transaction_record.processing_stage,
        metadata: transaction_record.metadata
      },
      metadata: {
        correlation_id: command.correlation_id,
        causation_id: command.causation_id,
        timestamp: command.timestamp,
        version: 1,
        hash_signature: generate_event_signature(transaction_record, command)
      }
    }
  end

  def self.build_transaction_verified_event(transaction_record, verification_result, command)
    {
      event_id: SecureRandom.uuid,
      event_type: 'BondTransactionVerified',
      aggregate_id: transaction_record.id,
      aggregate_type: 'BondTransaction',
      event_data: {
        status: 'verified',
        processing_stage: 'verified',
        verified_at: Time.current,
        verification_result: verification_result.to_h,
        financial_risk_score: verification_result.risk_score,
        verification_confidence: verification_result.confidence_score
      },
      metadata: {
        correlation_id: command.correlation_id,
        causation_id: command.causation_id,
        timestamp: Time.current,
        version: transaction_record.version + 1,
        hash_signature: generate_event_signature(transaction_record, command, verification_result)
      }
    }
  end

  def self.execute_transaction_verification(command, transaction_record, read_model)
    case command.verification_type
    when :fraud_detection
      execute_fraud_detection_verification(command, transaction_record, read_model)
    when :compliance_check
      execute_compliance_verification(command, transaction_record, read_model)
    else
      failure_result("Unsupported verification type: #{command.verification_type}")
    end
  end

  def self.execute_fraud_detection_verification(command, transaction_record, read_model)
    # Execute comprehensive fraud detection with ML
    fraud_detection_service = BondTransactionFraudDetectionService.new

    fraud_result = fraud_detection_service.analyze_transaction(
      transaction_state: BondTransactionState.from_transaction_record(transaction_record),
      verification_data: command.verification_data,
      read_model: read_model
    )

    success_result(fraud_result, "Fraud detection completed")
  end

  def self.execute_compliance_verification(command, transaction_record, read_model)
    # Execute compliance verification
    compliance_service = ComplianceValidationService.new

    compliance_result = compliance_service.verify_transaction_compliance(
      transaction_state: BondTransactionState.from_transaction_record(transaction_record),
      verification_data: command.verification_data,
      read_model: read_model
    )

    success_result(compliance_result, "Compliance verification completed")
  end

  def self.update_read_model_projection(read_model, event)
    # Update CQRS read model projection
    projector = BondTransactionProjector.new
    projector.apply_event(read_model, event)
    read_model.save!
  end

  def self.generate_event_signature(transaction_record, command, verification_result = nil)
    # Generate cryptographic signature for event integrity
    data = [
      transaction_record.id,
      command.correlation_id,
      command.timestamp.to_i,
      verification_result&.to_h&.hash || 0
    ].join('|')

    OpenSSL::HMAC.hexdigest('SHA256', ENV['EVENT_SIGNATURE_SECRET'] || 'default-secret', data)
  end

  def self.publish_transaction_creation_events(event, command)
    EventBus.publish(:bond_transaction_created,
      event: event,
      command: command,
      timestamp: command.timestamp,
      correlation_id: command.correlation_id
    )
  end

  def self.publish_transaction_verification_events(event, command)
    EventBus.publish(:bond_transaction_verified,
      event: event,
      command: command,
      timestamp: Time.current,
      correlation_id: command.correlation_id
    )
  end
end