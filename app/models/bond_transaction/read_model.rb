# frozen_string_literal: true

require_relative 'event_store'

# ═══════════════════════════════════════════════════════════════════════════════════
# CQRS READ MODEL PROJECTIONS
# ═══════════════════════════════════════════════════════════════════════════════════

# Read model for bond transaction queries
class BondTransactionReadModel < ApplicationRecord
  self.table_name = 'bond_transaction_read_models'

  belongs_to :bond, class_name: 'Bond', optional: true
  belongs_to :payment_transaction, class_name: 'PaymentTransaction', optional: true

  monetize :amount_cents

  enum transaction_type: {
    payment: 'payment',
    refund: 'refund',
    forfeiture: 'forfeiture',
    adjustment: 'adjustment',
    reversal: 'reversal',
    correction: 'correction'
  }

  enum status: {
    pending: 'pending',
    processing: 'processing',
    verified: 'verified',
    completed: 'completed',
    failed: 'failed',
    cancelled: 'cancelled'
  }

  enum processing_stage: {
    initialized: 'initialized',
    processing: 'processing',
    verified: 'verified',
    completed: 'completed',
    failed: 'failed'
  }

  # Optimized query methods for read operations
  def self.find_by_financial_risk_threshold(threshold = 0.7)
    where('financial_risk_score >= ?', threshold)
      .where('created_at >= ?', 24.hours.ago)
      .order(:financial_risk_score)
  end

  def self.transactions_requiring_verification
    where(status: [:pending, :processing])
      .where('created_at >= ?', 1.hour.ago)
      .where('financial_risk_score >= 0.5')
      .order(:created_at)
  end

  def self.performance_analytics(time_range = 30.days.ago..Time.current)
    # Use materialized view for performance analytics
    BondTransactionAnalyticsQuery.execute(time_range)
  end

  def self.predictive_risk_assessment(bond_id = nil)
    scope = bond_id ? where(bond_id: bond_id) : all
    recent_transactions = scope.where('created_at >= ?', 7.days.ago)

    return {} if recent_transactions.empty?

    risk_predictor = BondTransactionRiskPredictor.new(recent_transactions)
    risk_predictor.generate_risk_assessment
  end

  def refresh_from_events!
    # Refresh read model from event store
    events = BondTransactionEventStore.load_events(id)
    projector = BondTransactionProjector.new

    events.each do |event|
      projector.apply_event(self, event)
    end

    save! if changed?
  end
end

# Event projector for CQRS read model updates
class BondTransactionProjector
  def apply_event(read_model, event)
    case event[:event_type]
    when 'BondTransactionCreated'
      apply_transaction_created(read_model, event)
    when 'BondTransactionVerified'
      apply_transaction_verified(read_model, event)
    when 'BondTransactionCompleted'
      apply_transaction_completed(read_model, event)
    when 'BondTransactionFailed'
      apply_transaction_failed(read_model, event)
    end
  end

  private

  def apply_transaction_created(read_model, event)
    data = event[:event_data]

    read_model.assign_attributes(
      bond_id: data['bond_id'],
      payment_transaction_id: data['payment_transaction_id'],
      transaction_type: data['transaction_type'],
      amount_cents: data['amount_cents'],
      status: 'pending',
      processing_stage: 'initialized',
      created_at: event[:metadata][:timestamp],
      version: event[:metadata][:version]
    )
  end

  def apply_transaction_verified(read_model, event)
    data = event[:event_data]

    read_model.assign_attributes(
      status: 'verified',
      processing_stage: 'verified',
      verified_at: event[:metadata][:timestamp],
      financial_risk_score: data['financial_risk_score'],
      verification_confidence: data['verification_confidence']
    )
  end

  def apply_transaction_completed(read_model, event)
    data = event[:event_data]

    read_model.assign_attributes(
      status: 'completed',
      processing_stage: 'completed',
      completed_at: event[:metadata][:timestamp],
      processing_duration_seconds: data['processing_duration_seconds']
    )
  end

  def apply_transaction_failed(read_model, event)
    data = event[:event_data]

    read_model.assign_attributes(
      status: 'failed',
      processing_stage: 'failed',
      failed_at: event[:metadata][:timestamp],
      failure_reason: data['failure_reason']
    )
  end
end