# frozen_string_literal: true

# Domain event representing the capture of a new image
# This is the foundational event that starts the camera capture lifecycle
class ImageCapturedEvent < CameraCaptureEvent
  attr_reader :user_id, :capture_type, :image_metadata, :device_info, :capture_context

  # Create new image captured event
  # @param aggregate_id [String] camera capture aggregate ID
  # @param user_id [Integer] ID of user who captured the image
  # @param capture_type [CaptureType] type of capture operation
  # @param image_metadata [ImageMetadata] image properties and metadata
  # @param device_info [DeviceInfo] device that captured the image
  # @param capture_context [Hash] additional context about the capture
  # @param metadata [Hash] additional event metadata
  def initialize(
    aggregate_id,
    user_id:,
    capture_type:,
    image_metadata:,
    device_info:,
    capture_context: {},
    **metadata
  )
    super(aggregate_id, metadata: metadata)

    @user_id = user_id
    @capture_type = capture_type
    @image_metadata = image_metadata
    @device_info = device_info
    @capture_context = capture_context.freeze

    validate_event_data!
  end

  # Get event data for serialization
  # @return [Hash] serializable event data
  def event_data
    super.merge(
      user_id: @user_id,
      capture_type: @capture_type.to_s,
      image_metadata: @image_metadata.to_hash,
      device_info: @device_info.to_hash,
      capture_context: @capture_context
    )
  end

  # Get fraud risk score for this capture event
  # @return [Float] risk score 0.0-1.0
  def fraud_risk_score
    risk_factors = []

    # Device-based risk factors
    risk_factors << 0.3 if @device_info.suspicious_location?
    risk_factors << 0.2 unless @device_info.trusted_device?
    risk_factors << 0.1 unless @device_info.has_camera?

    # Capture type risk factors
    case @capture_type.fraud_risk
    when :critical then risk_factors << 0.9
    when :high then risk_factors << 0.7
    when :medium then risk_factors << 0.4
    when :low then risk_factors << 0.1
    end

    # Image quality risk factors
    risk_factors << 0.3 unless @image_metadata.meets_quality_requirements?(@capture_type)
    risk_factors << 0.2 if @image_metadata.file_size > @capture_type.retention_days * 1024 * 1024

    # Network risk factors
    risk_factors << 0.1 if @device_info.network_quality_score < 0.5

    # Calculate weighted average
    risk_factors.empty? ? 0.0 : risk_factors.reduce(:+) / risk_factors.length
  end

  # Check if this capture should trigger enhanced validation
  # @return [Boolean] true if enhanced validation needed
  def requires_enhanced_validation?
    fraud_risk_score > 0.6 || @capture_type.high_value?
  end

  # Get processing priority for this capture
  # @return [Integer] priority (lower = higher priority)
  def processing_priority
    priority = @capture_type.processing_priority

    # Adjust based on fraud risk
    priority -= 1 if fraud_risk_score > 0.7
    priority += 1 if fraud_risk_score < 0.2

    # Adjust based on device trust
    priority -= 1 if @device_info.trusted_device?

    priority
  end

  # Get expected processing time in seconds
  # @return [Integer] expected processing time
  def expected_processing_time
    base_time = case @capture_type.type
                when :product_photo then 30
                when :barcode_scan then 5
                when :ar_preview then 45
                when :visual_search then 25
                when :review_photo then 35
                when :profile_photo then 20
                when :document_scan then 60
                else 30
                end

    # Adjust based on image complexity
    complexity_multiplier = if @image_metadata.high_resolution?
                             1.5
                           elsif @image_metadata.megapixels > 8
                             1.2
                           else
                             1.0
                           end

    # Adjust based on fraud risk (higher risk = faster processing)
    risk_multiplier = fraud_risk_score > 0.5 ? 0.8 : 1.2

    (base_time * complexity_multiplier * risk_multiplier).to_i
  end

  # Get storage requirements for this capture
  # @return [Hash] storage requirements
  def storage_requirements
    {
      tier: @capture_type.storage_tier,
      retention_days: @capture_type.retention_days,
      replication_factor: @capture_type.high_value? ? 3 : 2,
      encryption_required: @capture_type.fraud_risk == :critical,
      backup_frequency: @capture_type.high_value? ? :daily : :weekly
    }
  end

  private

  # Validate event-specific data
  def validate_event_data!
    raise ArgumentError, 'User ID is required' unless @user_id
    raise ArgumentError, 'Capture type is required' unless @capture_type
    raise ArgumentError, 'Image metadata is required' unless @image_metadata
    raise ArgumentError, 'Device info is required' unless @device_info

    unless @image_metadata.within_file_size_limit?(@capture_type)
      raise ArgumentError, 'Image file size exceeds limit for capture type'
    end
  end
end