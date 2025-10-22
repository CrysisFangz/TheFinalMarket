class CameraCapture < ApplicationRecord
  # Associations with enhanced error handling and optional dependencies
  belongs_to :user, class_name: 'User', foreign_key: 'user_id'
  belongs_to :mobile_device, class_name: 'MobileDevice', foreign_key: 'mobile_device_id', optional: true
  belongs_to :product, class_name: 'Product', foreign_key: 'product_id', optional: true

  # Enhanced validations with custom error messages for better UX
  validates :user, presence: { message: "User is required for camera capture" }
  validates :capture_type, presence: { message: "Capture type must be specified" }
  validates :image_url, presence: { message: "Image URL is required" }, format: { with: URI::DEFAULT_PARSER.make_regexp, message: "Invalid URL format" }
  validates :captured_at, presence: { message: "Capture timestamp is required" }
  validates :processing_status, inclusion: { in: processing_statuses.keys, message: "Invalid processing status" }

  # Enums with comprehensive documentation
  enum capture_type: {
    product_photo: 0,    # High-resolution product images for listings
    barcode_scan: 1,     # Barcode scanning for inventory management
    ar_preview: 2,       # Augmented reality previews
    visual_search: 3,    # Visual search queries
    review_photo: 4,     # Customer review images
    profile_photo: 5,    # User profile pictures
    document_scan: 6     # Document scanning for verification
  }, _prefix: true

  enum processing_status: {
    pending: 0,          # Initial state, awaiting processing
    processing: 1,       # Currently being processed
    completed: 2,        # Successfully processed
    failed: 3            # Processing failed, requires retry
  }, _prefix: true

  # Scopes for efficient querying and performance optimization
  scope :pending_processing, -> { where(processing_status: :pending) }
  scope :completed_captures, -> { where(processing_status: :completed) }
  scope :failed_captures, -> { where(processing_status: :failed) }
  scope :by_capture_type, ->(type) { where(capture_type: type) }
  scope :recent_captures, ->(days = 7) { where('captured_at >= ?', days.days.ago) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :with_metadata, -> { where.not(capture_data: nil) }

  # Callbacks for automated processing and audit trails
  before_validation :set_defaults, if: :new_record?
  after_create :schedule_processing_job
  after_update :log_status_change, if: :saved_change_to_processing_status?

  # Enhanced capture method with robust error handling and service integration
  def self.capture(user, capture_type, image_data, device: nil, metadata: {})
    raise ArgumentError, "User is required" unless user.present?
    raise ArgumentError, "Invalid capture type: #{capture_type}" unless capture_types.key?(capture_type.to_s)
    raise ArgumentError, "Image data must include URL" unless image_data.is_a?(Hash) && image_data[:url].present?

    transaction do
      capture = create!(
        user: user,
        mobile_device: device,
        product: image_data[:product],
        capture_type: capture_type,
        image_url: image_data[:url],
        captured_at: Time.current,
        processing_status: :pending,
        capture_data: metadata,
        file_size: image_data[:file_size],
        image_format: image_data[:format]
      )

      # Trigger background processing
      CameraCaptureProcessingJob.perform_later(capture.id)

      capture
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Camera capture creation failed: #{e.message}")
    raise
  end

  # Instance methods for enhanced functionality
  def process_image
    update!(processing_status: :processing)
    # Placeholder for actual image processing logic
    # This could integrate with external services like AWS Rekognition or Google Vision
    update!(processing_status: :completed)
  rescue => e
    update!(processing_status: :failed)
    Rails.logger.error("Image processing failed for capture #{id}: #{e.message}")
  end

  def retry_processing
    return unless processing_status_failed?

    update!(processing_status: :pending)
    CameraCaptureProcessingJob.perform_later(id)
  end

  def metadata
    capture_data || {}
  end

  def image_size
    file_size || 0
  end

  private

  def set_defaults
    self.captured_at ||= Time.current
    self.processing_status ||= :pending
  end

  def schedule_processing_job
    CameraCaptureProcessingJob.perform_later(id)
  end

  def log_status_change
    AuditTrail.create!(
      auditable: self,
      action: 'status_change',
      changes: { from: processing_status_previously_was, to: processing_status },
      user: user,
      metadata: { capture_type: capture_type, image_url: image_url }
    )
  end
end

