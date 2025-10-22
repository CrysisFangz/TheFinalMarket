# frozen_string_literal: true

require_relative 'types'

# ═══════════════════════════════════════════════════════════════════════════════════
# DOMAIN LAYER: Immutable Bond Transaction Value Objects and Pure Functions
# ═══════════════════════════════════════════════════════════════════════════════════

# Immutable bond transaction state representation with formal verification
BondTransactionState = Struct.new(
  :transaction_id, :bond_id, :payment_transaction_id, :transaction_type,
  :amount_cents, :status, :processing_stage, :financial_impact,
  :created_at, :processed_at, :verified_at, :completed_at, :failed_at,
  :failure_reason, :retry_count, :metadata, :version, :hash_signature,
  :event_id, :correlation_id, :causation_id, :event_timestamp
) do
  def self.from_transaction_record(transaction_record)
    new(
      transaction_record.id,
      transaction_record.bond_id,
      transaction_record.payment_transaction_id,
      TransactionType.from_string(transaction_record.transaction_type || 'payment'),
      transaction_record.amount_cents,
      TransactionStatus.from_string(transaction_record.status || 'pending'),
      ProcessingStage.from_string(transaction_record.processing_stage || 'initialized'),
      FinancialImpact.from_amount(transaction_record.amount_cents, transaction_record.transaction_type),
      transaction_record.created_at,
      transaction_record.processed_at,
      transaction_record.verified_at,
      transaction_record.completed_at,
      transaction_record.failed_at,
      transaction_record.failure_reason,
      transaction_record.retry_count || 0,
      transaction_record.metadata || {},
      transaction_record.version || 1,
      transaction_record.hash_signature,
      transaction_record.event_id,
      transaction_record.correlation_id,
      transaction_record.causation_id,
      transaction_record.event_timestamp
    )
  end

  def with_processing_initiation(payment_transaction, processing_metadata = {})
    new(
      transaction_id,
      bond_id,
      payment_transaction&.id,
      transaction_type,
      amount_cents,
      status,
      ProcessingStage.from_string('processing'),
      financial_impact,
      created_at,
      Time.current,
      verified_at,
      completed_at,
      failed_at,
      failure_reason,
      retry_count,
      metadata.merge(
        processing_initiation: {
          payment_transaction_id: payment_transaction&.id,
          initiated_at: Time.current,
          processing_metadata: processing_metadata,
          node_id: SecureRandom.hex(8),
          processing_node_signature: generate_node_signature,
          correlation_id: metadata[:correlation_id] || SecureRandom.uuid,
          causation_id: SecureRandom.uuid
        }
      ),
      version + 1,
      generate_hash_signature,
      SecureRandom.uuid,
      metadata.dig(:processing_initiation, :correlation_id) || SecureRandom.uuid,
      transaction_id,
      Time.current
    )
  end

  def with_verification_completion(verification_result, verification_metadata = {})
    new(
      transaction_id,
      bond_id,
      payment_transaction_id,
      transaction_type,
      amount_cents,
      verification_result.success? ? TransactionStatus.from_string('verified') : status,
      ProcessingStage.from_string('verified'),
      financial_impact,
      created_at,
      processed_at,
      Time.current,
      completed_at,
      verification_result.success? ? nil : Time.current,
      verification_result.success? ? nil : verification_result.error_message,
      retry_count,
      metadata.merge(
        verification_completion: {
          verification_result: verification_result.to_h,
          verified_at: Time.current,
          verification_metadata: verification_metadata,
          confidence_score: calculate_verification_confidence(verification_result),
          correlation_id: metadata.dig(:verification_completion, :correlation_id) || SecureRandom.uuid,
          causation_id: SecureRandom.uuid
        }
      ),
      version + 1,
      generate_hash_signature,
      SecureRandom.uuid,
      metadata.dig(:verification_completion, :correlation_id) || SecureRandom.uuid,
      metadata.dig(:verification_completion, :causation_id) || transaction_id,
      Time.current
    )
  end

  def with_completion(completion_metadata = {})
    new(
      transaction_id,
      bond_id,
      payment_transaction_id,
      transaction_type,
      amount_cents,
      TransactionStatus.from_string('completed'),
      ProcessingStage.from_string('completed'),
      financial_impact,
      created_at,
      processed_at,
      verified_at,
      Time.current,
      failed_at,
      failure_reason,
      retry_count,
      metadata.merge(
        completion: {
          completed_at: Time.current,
          completion_metadata: completion_metadata,
          final_state_hash: generate_final_state_hash,
          correlation_id: metadata.dig(:completion, :correlation_id) || SecureRandom.uuid,
          causation_id: SecureRandom.uuid
        }
      ),
      version + 1,
      generate_hash_signature,
      SecureRandom.uuid,
      metadata.dig(:completion, :correlation_id) || SecureRandom.uuid,
      metadata.dig(:completion, :causation_id) || transaction_id,
      Time.current
    )
  end

  def with_failure(failure_reason, failure_metadata = {})
    new(
      transaction_id,
      bond_id,
      payment_transaction_id,
      transaction_type,
      amount_cents,
      TransactionStatus.from_string('failed'),
      ProcessingStage.from_string('failed'),
      financial_impact,
      created_at,
      processed_at,
      verified_at,
      completed_at,
      Time.current,
      failure_reason,
      retry_count + 1,
      metadata.merge(
        failure: {
          failed_at: Time.current,
          failure_reason: failure_reason,
          failure_metadata: failure_metadata,
          retry_count: retry_count + 1,
          max_retries: 3,
          can_retry: (retry_count + 1) < 3,
          correlation_id: metadata.dig(:failure, :correlation_id) || SecureRandom.uuid,
          causation_id: SecureRandom.uuid
        }
      ),
      version + 1,
      generate_hash_signature,
      SecureRandom.uuid,
      metadata.dig(:failure, :correlation_id) || SecureRandom.uuid,
      metadata.dig(:failure, :causation_id) || transaction_id,
      Time.current
    )
  end

  def calculate_financial_risk
    # Machine learning financial risk calculation for transaction
    BondTransactionRiskCalculator.calculate_financial_risk(self)
  end

  def predict_transaction_success_probability
    # Machine learning prediction of transaction success
    BondTransactionPredictor.predict_success_probability(self)
  end

  def generate_financial_insights
    # Generate financial insights for transaction
    BondTransactionInsightsGenerator.generate_insights(self)
  end

  def amount_formatted
    Money.new(amount_cents, 'USD').format
  end

  def processing_duration_seconds
    return 0 unless processed_at && created_at
    (processed_at - created_at).to_f
  end

  def total_duration_seconds
    end_time = [completed_at, failed_at, Time.current].compact.max
    (end_time - created_at).to_f
  end

  def immutable?
    true
  end

  def hash
    [transaction_id, version].hash
  end

  def eql?(other)
    other.is_a?(BondTransactionState) &&
      transaction_id == other.transaction_id &&
      version == other.version
  end

  def to_event
    {
      event_id: event_id,
      event_type: "BondTransaction#{status.to_s.capitalize}",
      aggregate_id: transaction_id,
      aggregate_type: 'BondTransaction',
      event_data: to_h.except(:hash_signature),
      metadata: {
        correlation_id: correlation_id,
        causation_id: causation_id,
        timestamp: event_timestamp,
        version: version,
        hash_signature: hash_signature
      }
    }
  end

  private

  def generate_hash_signature
    # Cryptographic hash for transaction state immutability verification
    data = [transaction_id, amount_cents, status.to_s, version, Time.current.to_i].join('|')
    OpenSSL::HMAC.hexdigest('SHA256', ENV['TRANSACTION_HASH_SECRET'] || 'default-secret', data)
  end

  def generate_node_signature
    # Generate unique node signature for distributed processing
    node_data = [Socket.gethostname, Process.pid, Time.current.to_f].join('|')
    Digest::SHA256.hexdigest(node_data)
  end

  def generate_final_state_hash
    # Generate final state hash for audit trail
    final_data = [
      transaction_id, bond_id, payment_transaction_id, amount_cents,
      status.to_s, completed_at.to_i
    ].join('|')
    Digest::SHA256.hexdigest(final_data)
  end

  def calculate_verification_confidence(verification_result)
    # Calculate confidence score for verification result
    base_confidence = verification_result.confidence_score || 0.5

    # Adjust based on amount and transaction type
    amount_multiplier = case Money.new(amount_cents, 'USD').amount
    when 0..100 then 0.9
    when 100..500 then 0.8
    when 500..1000 then 0.7
    else 0.6
    end

    risk_multiplier = case transaction_type.value
    when :payment then 0.8
    when :refund then 0.9
    when :forfeiture then 0.7
    else 0.5
    end

    [base_confidence * amount_multiplier * risk_multiplier, 1.0].min
  end
end