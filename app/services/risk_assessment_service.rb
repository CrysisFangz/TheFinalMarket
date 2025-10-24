class RiskAssessmentService
  def self.set_risk_level(fraud_check)
    fraud_check.risk_level = if fraud_check.risk_score >= 80
      :critical
    elsif fraud_check.risk_score >= 70
      :high
    elsif fraud_check.risk_score >= 40
      :medium
    else
      :low
    end
  end

  def self.high_risk?(fraud_check)
    Rails.cache.fetch("fraud_check:#{fraud_check.id}:high_risk", expires_in: 1.hour) do
      fraud_check.risk_score >= 70
    end
  end

  def self.requires_action?(fraud_check)
    Rails.cache.fetch("fraud_check:#{fraud_check.id}:requires_action", expires_in: 1.hour) do
      high_risk?(fraud_check) && fraud_check.action_taken == 'none'
    end
  end

  def self.get_risk_description(fraud_check)
    Rails.cache.fetch("fraud_check:#{fraud_check.id}:risk_description", expires_in: 1.hour) do
      case fraud_check.risk_level.to_sym
      when :critical
        "Critical Risk - Immediate action required"
      when :high
        "High Risk - Review recommended"
      when :medium
        "Medium Risk - Monitor closely"
      when :low
        "Low Risk - Normal activity"
      end
    end
  end
end