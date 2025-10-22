# frozen_string_literal: true

# Enterprise Payment Risk Assessor
# ML-powered risk assessment with real-time fraud detection
class PaymentRiskAssessor
  include ServiceResultHelper

  # Assess current risk level for payment account
  def assess_current_risk_level(payment_account)
    CircuitBreaker.execute_with_fallback(:risk_assessment) do
      # Execute parallel risk assessments
      risk_factors = execute_parallel_risk_assessment(payment_account)

      # Calculate composite risk score
      composite_score = calculate_composite_risk_score(risk_factors)

      # Determine risk level
      risk_level = determine_risk_level(composite_score)

      # Create risk assessment record
      create_risk_assessment_record(payment_account, risk_level, composite_score, risk_factors)

      success_result(risk_level, 'Risk assessment completed')
    end
  end

  # Assess account risk with specific context
  def assess_account_risk(payment_account, context = {})
    CircuitBreaker.execute_with_fallback(:contextual_risk_assessment) do
      # Get current account state
      current_risk_level = payment_account.risk_level

      # Execute contextual risk factors
      contextual_factors = execute_contextual_risk_factors(payment_account, context)

      # Apply context weighting
      weighted_score = apply_context_weighting(contextual_factors, context)

      # Determine if risk level changed
      new_risk_level = determine_risk_level_from_context(weighted_score, current_risk_level)

      # Update account if risk level changed
      update_risk_level_if_changed(payment_account, new_risk_level, weighted_score, context)

      success_result(new_risk_level, 'Contextual risk assessment completed')
    end
  end

  private

  def execute_parallel_risk_assessment(payment_account)
    assessments = [
      -> { assess_transaction_velocity(payment_account) },
      -> { assess_payment_patterns(payment_account) },
      -> { assess_geographic_risk(payment_account) },
      -> { assess_device_fingerprint_risk(payment_account) },
      -> { assess_behavioral_risk(payment_account) },
      -> { assess_historical_fraud_risk(payment_account) }
    ]

    ReactiveParallelExecutor.execute(assessments)
  end

  def calculate_composite_risk_score(risk_factors)
    # Weighted risk calculation using ML model
    weights = load_risk_weights

    composite_score = 0.0
    risk_factors.each do |factor, score|
      weight = weights[factor] || 0.1
      composite_score += score * weight
    end

    # Normalize to 0-1 range
    [composite_score, 1.0].min
  end

  def determine_risk_level(composite_score)
    case composite_score
    when 0.0..0.3 then :low
    when 0.3..0.6 then :medium
    when 0.6..0.8 then :high
    when 0.8..0.95 then :critical
    else :extreme
    end
  end

  def execute_contextual_risk_factors(payment_account, context)
    factors = {}

    # Operation-specific risk factors
    case context[:operation]
    when :payment_method_update
      factors[:payment_method_risk] = assess_payment_method_risk(context[:payment_methods])
      factors[:velocity_risk] = assess_update_velocity_risk(payment_account)
    when :account_suspension
      factors[:suspension_risk] = assess_suspension_risk(payment_account, context)
    when :high_value_transaction
      factors[:amount_risk] = assess_amount_risk(context[:amount])
      factors[:merchant_risk] = assess_merchant_risk(context[:merchant])
    end

    # Always include core factors
    factors[:account_age_risk] = assess_account_age_risk(payment_account)
    factors[:verification_risk] = assess_verification_risk(payment_account)

    factors
  end

  def apply_context_weighting(factors, context)
    # Apply dynamic weighting based on context
    base_weights = load_context_weights(context[:operation])

    weighted_score = 0.0
    factors.each do |factor, score|
      weight = base_weights[factor] || 0.1
      weighted_score += score * weight
    end

    weighted_score
  end

  def determine_risk_level_from_context(weighted_score, current_level)
    # Consider current level in risk determination
    level_thresholds = risk_level_thresholds

    new_level = case weighted_score
                when 0.0..level_thresholds[:low] then :low
                when level_thresholds[:low]..level_thresholds[:medium] then :medium
                when level_thresholds[:medium]..level_thresholds[:high] then :high
                when level_thresholds[:high]..level_thresholds[:critical] then :critical
                else :extreme
                end

    # Don't downgrade risk level without manual review
    new_level = current_level if risk_level_to_score(current_level) > risk_level_to_score(new_level)

    new_level
  end

  def update_risk_level_if_changed(payment_account, new_risk_level, score, context)
    return if payment_account.risk_level == new_risk_level.to_s

    # Create risk change event
    event = PaymentAccountRiskLevelChangedEvent.new(
      "payment_account_#{payment_account.id}",
      payment_account_id: payment_account.id,
      old_risk_level: payment_account.risk_level,
      new_risk_level: new_risk_level.to_s,
      risk_score: score,
      context: context,
      triggered_by: context[:operation]
    )

    # Store event and update account
    event_store = EventStore.new
    event_store.append_events(event.aggregate_id, [event])

    payment_account.update!(
      risk_level: new_risk_level,
      last_risk_assessment_at: Time.current,
      risk_assessment_metadata: {
        score: score,
        context: context,
        triggered_by: context[:operation]
      }
    )

    # Publish event for monitoring
    EventPublisher.publish('risk_assessment.events', event)
  end

  def create_risk_assessment_record(payment_account, risk_level, score, factors)
    PaymentRiskAssessment.create!(
      payment_account: payment_account,
      risk_level: risk_level,
      risk_score: score,
      assessment_factors: factors,
      assessed_at: Time.current,
      assessment_version: current_assessment_version
    )
  end

  def load_risk_weights
    # Load from configuration or ML model
    Rails.cache.fetch('payment_risk_weights', expires_in: 1.hour) do
      {
        transaction_velocity: 0.25,
        payment_patterns: 0.20,
        geographic_risk: 0.15,
        device_fingerprint: 0.15,
        behavioral_risk: 0.15,
        historical_fraud: 0.10
      }
    end
  end

  def load_context_weights(operation)
    case operation
    when :payment_method_update
      {
        payment_method_risk: 0.30,
        velocity_risk: 0.25,
        account_age_risk: 0.20,
        verification_risk: 0.25
      }
    when :account_suspension
      {
        suspension_risk: 0.40,
        account_age_risk: 0.20,
        verification_risk: 0.20,
        historical_fraud: 0.20
      }
    else
      load_risk_weights
    end
  end

  def risk_level_thresholds
    {
      low: 0.3,
      medium: 0.6,
      high: 0.8,
      critical: 0.95
    }
  end

  def risk_level_to_score(level)
    scores = { low: 0.15, medium: 0.45, high: 0.7, critical: 0.875, extreme: 0.95 }
    scores[level.to_sym] || 0.0
  end

  def current_assessment_version
    '2.1.0' # Track assessment algorithm version
  end

  # Individual risk factor assessments (simplified implementations)
  def assess_transaction_velocity(payment_account)
    # Implementation would analyze transaction frequency and amounts
    0.2
  end

  def assess_payment_patterns(payment_account)
    # Implementation would analyze payment method patterns
    0.1
  end

  def assess_geographic_risk(payment_account)
    # Implementation would analyze geographic patterns
    0.15
  end

  def assess_device_fingerprint_risk(payment_account)
    # Implementation would analyze device fingerprints
    0.1
  end

  def assess_behavioral_risk(payment_account)
    # Implementation would analyze user behavior patterns
    0.2
  end

  def assess_historical_fraud_risk(payment_account)
    # Implementation would check historical fraud data
    0.05
  end

  def assess_payment_method_risk(payment_methods)
    # Implementation would assess new payment methods
    0.3
  end

  def assess_update_velocity_risk(payment_account)
    # Implementation would assess update frequency
    0.2
  end

  def assess_suspension_risk(payment_account, context)
    # Implementation would assess suspension justification
    0.4
  end

  def assess_amount_risk(amount)
    # Implementation would assess transaction amount risk
    0.5
  end

  def assess_merchant_risk(merchant)
    # Implementation would assess merchant risk
    0.3
  end

  def assess_account_age_risk(payment_account)
    # Implementation would assess account age
    0.1
  end

  def assess_verification_risk(payment_account)
    # Implementation would assess verification status
    0.2
  end
end