class ExchangeRate < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :currency

  validates :rate, presence: true, numericality: { greater_than: 0 }
  validates :source, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_currency, ->(currency) { where(currency: currency) }
  scope :today, -> { where('created_at >= ?', Date.current.beginning_of_day) }

  # Sources for exchange rates
  enum source: {
    manual: 0,
    api_fixer: 1,
    api_openexchangerates: 2,
    api_currencyapi: 3,
    api_exchangerate: 4
  }

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Get the latest rate for a currency pair
  def self.latest_rate(from_currency, to_currency)
    RateLookupService.latest_rate(from_currency, to_currency)
  end

  # Calculate cross rate between two currencies
  def self.cross_rate(from_currency, to_currency)
    RateCalculationService.cross_rate(from_currency, to_currency)
  end

  # Check if rate has changed significantly
  def significant_change?(threshold_percentage = 2)
    RateAnalysisService.significant_change?(self, threshold_percentage)
  end

  private

  def publish_created_event
    EventPublisher.publish('exchange_rate.created', {
      rate_id: id,
      currency_id: currency_id,
      rate: rate,
      source: source,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('exchange_rate.updated', {
      rate_id: id,
      currency_id: currency_id,
      rate: rate,
      source: source,
      significant_change: significant_change?,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('exchange_rate.destroyed', {
      rate_id: id,
      currency_id: currency_id,
      rate: rate,
      source: source
    })
  end
end