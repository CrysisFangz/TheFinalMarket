class CameraCapture < ApplicationRecord
  belongs_to :user
  belongs_to :mobile_device, optional: true
  belongs_to :product, optional: true
  
  validates :user, presence: true
  validates :capture_type, presence: true
  
  enum capture_type: {
    product_photo: 0,
    barcode_scan: 1,
    ar_preview: 2,
    visual_search: 3,
    review_photo: 4,
    profile_photo: 5,
    document_scan: 6
  }
  
  enum processing_status: {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }
  
  # Capture image
  def self.capture(user, capture_type, image_data, device: nil, metadata: {})
    create!(
      user: user,
      mobile_device: device,
      capture_type: capture_type,
      image_url: image_data[:url],
      captured_at: Time.current,
      processing_status: :pending,
      capture_data: metadata
    )
  end
end

