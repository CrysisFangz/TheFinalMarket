class FraudRule < ApplicationRecord
  include CircuitBreaker
  include Retryable

  validates :name, presence: true
  validates :rule_type, presence: true
  validates :risk_weight, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :active, -> { where(active: true) }
  scope :by_priority, -> { order(priority: :asc) }

  # Rule types
  enum rule_type: {
    velocity_check: 0,
    amount_threshold: 1,
    location_check: 2,
    device_check: 3,
    time_check: 4,
    pattern_check: 5,
    blacklist_check: 6,
    reputation_check: 7,
    custom: 9
  }

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Evaluate rule against context
  def evaluate(context)
    with_retry do
      RuleEvaluationService.evaluate(self, context)
    end
  end

  private

  def publish_created_event
    EventPublisher.publish('fraud_rule.created', {
      rule_id: id,
      name: name,
      rule_type: rule_type,
      risk_weight: risk_weight,
      priority: priority,
      active: active?,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('fraud_rule.updated', {
      rule_id: id,
      name: name,
      rule_type: rule_type,
      risk_weight: risk_weight,
      priority: priority,
      active: active?,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('fraud_rule.destroyed', {
      rule_id: id,
      name: name,
      rule_type: rule_type,
      risk_weight: risk_weight
    })
  end
end