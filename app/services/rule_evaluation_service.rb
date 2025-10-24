class RuleEvaluationService
  def self.evaluate(rule, context)
    return false unless rule.active?

    Rails.cache.fetch("fraud_rule:#{rule.id}:evaluation:#{context.hash}", expires_in: 5.minutes) do
      case rule.rule_type.to_sym
      when :velocity_check
        VelocityEvaluationService.evaluate(rule, context)
      when :amount_threshold
        AmountEvaluationService.evaluate(rule, context)
      when :location_check
        LocationEvaluationService.evaluate(rule, context)
      when :device_check
        DeviceEvaluationService.evaluate(rule, context)
      when :time_check
        TimeEvaluationService.evaluate(rule, context)
      when :pattern_check
        PatternEvaluationService.evaluate(rule, context)
      when :blacklist_check
        BlacklistEvaluationService.evaluate(rule, context)
      when :reputation_check
        ReputationEvaluationService.evaluate(rule, context)
      else
        false
      end
    end
  end
end