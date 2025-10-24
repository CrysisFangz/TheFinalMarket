class FraudRulePresenter
  def initialize(rule)
    @rule = rule
  end

  def as_json(options = {})
    {
      id: @rule.id,
      name: @rule.name,
      description: @rule.description,
      rule_type: @rule.rule_type,
      risk_weight: @rule.risk_weight,
      priority: @rule.priority,
      active: @rule.active?,
      conditions: @rule.conditions,
      created_at: @rule.created_at,
      updated_at: @rule.updated_at
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end