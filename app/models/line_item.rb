class LineItem < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :product
  belongs_to :cart

  # Caching
  after_create :clear_line_item_cache
  after_update :clear_line_item_cache
  after_destroy :clear_line_item_cache

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  def total_price
    LineItemPricingService.calculate_total_price(self)[:total_price]
  end
