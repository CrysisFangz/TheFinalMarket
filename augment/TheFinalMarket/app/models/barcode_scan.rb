# app/models/barcode_scan.rb
class BarcodeScan < ApplicationRecord
  belongs_to :user
  belongs_to :product, optional: true
  
  validates :barcode, presence: true
  validates :scanned_at, presence: true
  
  scope :recent, -> { order(scanned_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_barcode, ->(barcode) { where(barcode: barcode) }
  
  # Get scan history for user
  def self.history_for_user(user, limit: 50)
    for_user(user).recent.limit(limit)
  end
  
  # Get popular scanned products
  def self.popular_scans(limit: 10)
    where.not(product_id: nil)
      .group(:product_id)
      .order('COUNT(*) DESC')
      .limit(limit)
      .pluck(:product_id)
  end
end

