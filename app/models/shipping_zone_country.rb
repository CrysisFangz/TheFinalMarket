class ShippingZoneCountry < ApplicationRecord
  belongs_to :shipping_zone
  belongs_to :country

  # Validations for data integrity
  validates :shipping_zone_id, presence: true, uniqueness: { scope: :country_id }
  validates :country_id, presence: true

  # Scopes for clarity and common queries
  scope :for_zone, ->(zone_id) { where(shipping_zone_id: zone_id) }
  scope :for_country, ->(country_id) { where(country_id: country_id) }
  scope :active_zones, -> { joins(:shipping_zone).where(shipping_zones: { active: true }) }

  # Callbacks for cache invalidation and event publishing
  after_create :invalidate_caches_and_publish_event
  after_destroy :invalidate_caches_and_publish_event

  private

  def invalidate_caches_and_publish_event
    # Invalidate caches in ShippingZoneService
    ShippingZoneService.invalidate_cache(shipping_zone_id)

    # Publish event for scalability and auditability
    EventPublisher.publish('shipping_zone_country.changed', {
      action: self.destroyed? ? 'destroyed' : 'created',
      shipping_zone_id: shipping_zone_id,
      country_id: country_id,
      timestamp: Time.current
    })
  end
end

