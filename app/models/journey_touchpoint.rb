class JourneyTouchpoint < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :cross_channel_journey
  belongs_to :sales_channel

  validates :cross_channel_journey, presence: true
  validates :sales_channel, presence: true
  validates :action, presence: true

  # Caching
  after_create :clear_touchpoint_cache
  after_update :clear_touchpoint_cache
  after_destroy :clear_touchpoint_cache

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Get touchpoint summary
  def summary
    JourneyTouchpointManagementService.get_touchpoint_summary(self)
  end

