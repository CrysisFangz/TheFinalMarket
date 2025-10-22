# frozen_string_literal: true

require_relative 'state'
require_relative 'types'

# ═══════════════════════════════════════════════════════════════════════════════════
# MACHINE LEARNING ENHANCED RISK CALCULATION
# ═══════════════════════════════════════════════════════════════════════════════════

# Pure function bond transaction risk calculator with ML integration
class BondTransactionRiskCalculator
  class << self
    def calculate_financial_risk(transaction_state)
      # Multi-factor financial risk calculation with ML enhancement
      risk_factors = calculate_financial_risk_factors(transaction_state)
      ml_enhanced_score = apply_machine_learning_risk_model(risk_factors, transaction_state)
      weighted_risk_score = calculate_weighted_financial_risk_score(risk_factors, ml_enhanced_score)

      # Cache risk calculation for performance
      Rails.cache.write(
        "bond_transaction_financial_risk_#{transaction_state.transaction_id}",
        {
          score: weighted_risk_score,
          factors: risk_factors,
          ml_score: ml_enhanced_score,
          calculated_at: Time.current
        },
        expires_in: 30.minutes
      )

      weighted_risk_score
    end

    private

    def calculate_financial_risk_factors(transaction_state)
      factors = {}

      # Amount-based financial risk
      factors[:amount_risk] = calculate_amount_financial_risk(transaction_state.amount_cents)

      # Transaction type risk
      factors[:type_risk] = calculate_transaction_type_risk(transaction_state.transaction_type)

      # Processing stage risk
      factors[:stage_risk] = calculate_processing_stage_risk(transaction_state.processing_stage)

      # Historical pattern risk
      factors[:pattern_risk] = calculate_historical_pattern_risk(transaction_state)

      # Temporal risk (time-based patterns)
      factors[:temporal_risk] = calculate_temporal_risk(transaction_state)

      # Metadata analysis risk
      factors[:metadata_risk] = calculate_metadata_risk(transaction_state.metadata)

      # ML-enhanced behavioral risk
      factors[:behavioral_risk] = calculate_behavioral_risk(transaction_state)

      factors
    end

    def calculate_amount_financial_risk(amount_cents)
      amount_usd = amount_cents / 100.0

      case amount_usd
      when 0..100 then 0.1     # Low financial risk
      when 100..500 then 0.3   # Medium financial risk
      when 500..1000 then 0.6  # High financial risk
      else 0.9                 # Very high financial risk
      end
    end

    def calculate_transaction_type_risk(transaction_type)
      risk_mapping = {
        'payment' => 0.2,
        'refund' => 0.4,
        'forfeiture' => 0.1,
        'adjustment' => 0.1,
        'reversal' => 0.5,
        'correction' => 0.1
      }

      risk_mapping[transaction_type.to_s] || 0.3
    end

    def calculate_processing_stage_risk(processing_stage)
      risk_mapping = {
        'initialized' => 0.1,
        'processing' => 0.3,
        'verified' => 0.2,
        'completed' => 0.0,
        'failed' => 0.8
      }

      risk_mapping[processing_stage.to_s] || 0.2
    end

    def calculate_historical_pattern_risk(transaction_state)
      # Analyze historical patterns for similar transactions
      similar_transactions = BondTransaction.where(
        bond_id: transaction_state.bond_id,
        transaction_type: transaction_state.transaction_type.to_s
      ).where('created_at >= ?', 30.days.ago)

      return 0.5 if similar_transactions.empty?

      # Calculate failure rate in similar transactions
      failure_rate = similar_transactions.where(status: :failed).count.to_f / similar_transactions.count

      # Risk increases with higher failure rates
      failure_rate * 0.8
    end

    def calculate_temporal_risk(transaction_state)
      # Time-based risk analysis
      current_hour = Time.current.hour
      current_day = Time.current.wday

      # Higher risk during off-hours and weekends
      hour_risk = current_hour < 6 || current_hour > 22 ? 0.3 : 0.1
      day_risk = [0, 6].include?(current_day) ? 0.2 : 0.0

      hour_risk + day_risk
    end

    def calculate_metadata_risk(metadata)
      # Analyze metadata for risk indicators
      risk_score = 0.0

      # Check for suspicious patterns in metadata
      if metadata['automated_processing'] == true
        risk_score += 0.1
      end

      if metadata['retry_count'].to_i > 2
        risk_score += 0.4
      end

      if metadata['ip_address'].present?
        # Basic IP-based risk (in production, integrate with IP reputation services)
        risk_score += 0.1
      end

      [risk_score, 1.0].min
    end

    def calculate_behavioral_risk(transaction_state)
      # ML-enhanced behavioral pattern analysis
      behavioral_analyzer = TransactionBehavioralAnalyzer.new
      behavioral_analyzer.analyze_transaction_patterns(transaction_state)
    end

    def apply_machine_learning_risk_model(risk_factors, transaction_state)
      # Apply pre-trained ML model for risk prediction
      ml_predictor = BondTransactionMLPredictor.new

      prediction = ml_predictor.predict_risk(
        amount_cents: transaction_state.amount_cents,
        transaction_type: transaction_state.transaction_type.to_s,
        bond_id: transaction_state.bond_id,
        metadata: transaction_state.metadata
      )

      prediction[:risk_score] || 0.5
    end

    def calculate_weighted_financial_risk_score(risk_factors, ml_score)
      # Enhanced weighted risk calculation with ML integration
      weights = {
        amount_risk: 0.20,
        type_risk: 0.15,
        stage_risk: 0.10,
        pattern_risk: 0.20,
        temporal_risk: 0.10,
        metadata_risk: 0.10,
        behavioral_risk: 0.15
      }

      # Combine traditional scoring with ML insights
      traditional_score = risk_factors.sum do |factor, score|
        weights[factor] * score
      end

      # Weighted combination of traditional and ML approaches
      (traditional_score * 0.7) + (ml_score * 0.3)
    end
  end
end

# ═══════════════════════════════════════════════════════════════════════════════════
# MACHINE LEARNING INTEGRATION: Advanced Transaction Intelligence
# ═══════════════════════════════════════════════════════════════════════════════════

class BondTransactionMLPredictor
  def predict_risk(amount_cents:, transaction_type:, bond_id:, metadata: {})
    # Load pre-trained ML model for risk prediction
    model = load_risk_prediction_model

    # Prepare features for prediction
    features = extract_prediction_features(amount_cents, transaction_type, bond_id, metadata)

    # Execute prediction
    prediction = model.predict(features)

    {
      risk_score: prediction[:risk_probability],
      confidence: prediction[:confidence],
      risk_factors: prediction[:risk_factors],
      prediction_timestamp: Time.current
    }
  end

  private

  def load_risk_prediction_model
    # Load TensorFlow/PyTorch model for risk prediction
    # In production, this would load from model registry
    @model ||= begin
      model_path = Rails.root.join('models', 'bond_transaction_risk_model')
      TensorFlowModelLoader.load(model_path) if File.exist?(model_path)
    end
  end

  def extract_prediction_features(amount_cents, transaction_type, bond_id, metadata)
    # Extract relevant features for ML prediction
    {
      amount_cents: amount_cents,
      transaction_type: transaction_type,
      bond_id: bond_id,
      hour_of_day: Time.current.hour,
      day_of_week: Time.current.wday,
      automated_processing: metadata['automated_processing'] || false,
      retry_count: metadata['retry_count'] || 0,
      ip_risk_score: calculate_ip_risk_score(metadata['ip_address']),
      historical_failure_rate: calculate_historical_failure_rate(bond_id, transaction_type)
    }
  end

  def calculate_ip_risk_score(ip_address)
    return 0.5 unless ip_address

    # Integrate with IP reputation service
    ip_analyzer = IPReputationAnalyzer.new
    ip_analyzer.analyze_risk(ip_address)
  end

  def calculate_historical_failure_rate(bond_id, transaction_type)
    # Calculate historical failure rate for similar transactions
    similar_transactions = BondTransaction.where(
      bond_id: bond_id,
      transaction_type: transaction_type
    ).where('created_at >= ?', 30.days.ago)

    return 0.0 if similar_transactions.empty?

    similar_transactions.where(status: :failed).count.to_f / similar_transactions.count
  end
end

# Behavioral pattern analyzer for transaction intelligence
class TransactionBehavioralAnalyzer
  def analyze_transaction_patterns(transaction_state)
    # Analyze behavioral patterns using ML
    pattern_analyzer = BehavioralPatternAnalyzer.new

    patterns = pattern_analyzer.analyze do |analyzer|
      analyzer.extract_temporal_patterns(transaction_state)
      analyzer.extract_amount_patterns(transaction_state)
      analyzer.extract_frequency_patterns(transaction_state)
      analyzer.extract_contextual_patterns(transaction_state)
    end

    # Calculate behavioral risk score
    calculate_behavioral_risk_score(patterns)
  end

  private

  def calculate_behavioral_risk_score(patterns)
    # Calculate risk based on behavioral patterns
    risk_score = 0.0

    # Unusual timing patterns
    risk_score += 0.2 if patterns[:unusual_timing]

    # Unusual amount patterns
    risk_score += 0.3 if patterns[:unusual_amounts]

    # High frequency patterns
    risk_score += 0.2 if patterns[:high_frequency]

    # Suspicious contextual patterns
    risk_score += 0.3 if patterns[:suspicious_context]

    [risk_score, 1.0].min
  end
end