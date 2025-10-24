class RiskFactorsService
  def self.get_risk_factors_array(fraud_check)
    Rails.cache.fetch("fraud_check:#{fraud_check.id}:risk_factors_array", expires_in: 1.hour) do
      fraud_check.factors['factors'] || []
    end
  end

  def self.add_risk_factor(fraud_check, factor, weight)
    fraud_check.factors ||= { 'factors' => [] }
    fraud_check.factors['factors'] << { 'factor' => factor, 'weight' => weight }
  end
end