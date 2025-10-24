class ShippingZone < ApplicationRecord
  has_many :shipping_zone_countries, dependent: :destroy
  has_many :countries, through: :shipping_zone_countries
  has_many :shipping_rates, dependent: :destroy

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  validates :priority, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :by_priority, -> { order(priority: :asc) }

  # Invalidate caches when zone is updated
  after_save :invalidate_caches
  after_destroy :invalidate_caches

  private

  def invalidate_caches
    ShippingZoneService.invalidate_cache(id)
    ShippingRateCalculator.invalidate_cache(id)
  end
end

