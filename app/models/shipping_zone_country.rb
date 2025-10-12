class ShippingZoneCountry < ApplicationRecord
  belongs_to :shipping_zone
  belongs_to :country
  
  validates :shipping_zone_id, uniqueness: { scope: :country_id }
end

