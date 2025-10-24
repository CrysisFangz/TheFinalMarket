class VelocityEvaluationService
  def self.evaluate(rule, context)
    return false unless context[:user]

    threshold = rule.conditions['threshold'] || 10
    timeframe = rule.conditions['timeframe'] || 3600 # seconds

    count = FraudCheck.where(user: context[:user])
                      .where('created_at > ?', timeframe.seconds.ago)
                      .count

    count > threshold
  end
end