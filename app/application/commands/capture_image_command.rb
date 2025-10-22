# frozen_string_literal: true

# Command for capturing a new image
# Encapsulates the business operation of image capture with validation and error handling
class CaptureImageCommand
  # Command result
  CommandResult = Struct.new(:success?, :aggregate_id, :event, :error_message, keyword_init: true)

  attr_reader :user_id, :capture_type, :image_data, :device_info, :metadata

  # Initialize the command
  # @param user_id [Integer] ID of user capturing the image
  # @param capture_type [Symbol] type of capture operation
  # @param image_data [Hash] image data including URL and metadata
  # @param device_info [Hash] device information
  # @param metadata [Hash] additional context metadata
  def initialize(user_id:, capture_type:, image_data:, device_info: {}, metadata: {})
    @user_id = user_id
    @capture_type = capture_type.to_sym
    @image_data = image_data
    @device_info = device_info
    @metadata = metadata

    validate!
  end

  # Execute the capture operation
  # @return [CommandResult] operation result
  def execute
    validate_command!

    aggregate_id = generate_aggregate_id

    # Create value objects
    capture_type_vo = create_capture_type
    image_metadata_vo = create_image_metadata
    device_info_vo = create_device_info

    # Validate business rules
    validation_result = validate_business_rules(capture_type_vo, image_metadata_vo, device_info_vo)
    return CommandResult.new(success?: false, error_message: validation_result) unless validation_result.nil?

    # Create domain entity
    entity = CameraCapture.new(aggregate_id, @user_id, capture_type_vo, image_metadata_vo, device_info_vo)

    # Generate domain event
    event = ImageCapturedEvent.new(
      aggregate_id,
      user_id: @user_id,
      capture_type: capture_type_vo,
      image_metadata: image_metadata_vo,
      device_info: device_info_vo,
      capture_context: @metadata
    )

    entity.apply_event(event)
    entity.add_uncommitted_event(event)

    # Publish to event store (would be handled by infrastructure)
    publish_events(entity)

    CommandResult.new(success?: true, aggregate_id: aggregate_id, event: event)
  rescue StandardError => e
    CommandResult.new(success?: false, error_message: e.message)
  end

  private

  # Validate command parameters
  def validate!
    raise ArgumentError, 'User ID is required' unless @user_id
    raise ArgumentError, 'Capture type is required' if @capture_type.blank?
    raise ArgumentError, 'Image data is required' if @image_data.blank?
    raise ArgumentError, 'Image URL is required' if @image_data[:url].blank?
  end

  # Validate business rules before execution
  def validate_command!
    # Rate limiting validation
    rate_limit_result = validate_rate_limits
    raise ArgumentError, rate_limit_result unless rate_limit_result.nil?

    # Device validation
    device_validation = validate_device
    raise ArgumentError, device_validation unless device_validation.nil?

    # Image validation
    image_validation = validate_image
    raise ArgumentError, image_validation unless image_validation.nil?
  end

  # Generate unique aggregate ID
  # @return [String] unique identifier
  def generate_aggregate_id
    "capture_#{Time.current.to_i}_#{SecureRandom.hex(8)}"
  end

  # Create capture type value object
  # @return [CaptureType] capture type object
  def create_capture_type
    CaptureType.from_symbol(@capture_type)
  rescue ArgumentError => e
    raise ArgumentError, "Invalid capture type: #{e.message}"
  end

  # Create image metadata value object
  # @return [ImageMetadata] image metadata object
  def create_image_metadata
    # Extract or analyze image metadata
    metadata_params = extract_image_metadata

    ImageMetadata.new(
      width: metadata_params[:width],
      height: metadata_params[:height],
      file_size: metadata_params[:file_size],
      format: metadata_params[:format],
      quality_score: metadata_params[:quality_score],
      exif_data: metadata_params[:exif_data] || {},
      device_info: @device_info,
      capture_timestamp: Time.current,
      checksum: metadata_params[:checksum]
    )
  rescue ArgumentError => e
    raise ArgumentError, "Invalid image metadata: #{e.message}"
  end

  # Create device info value object
  # @return [DeviceInfo] device info object
  def create_device_info
    DeviceInfo.new(
      device_id: @device_info[:device_id] || 'unknown',
      device_type: @device_info[:device_type] || :smartphone,
      operating_system: @device_info[:operating_system] || :unknown,
      app_version: @device_info[:app_version],
      camera_capabilities: @device_info[:camera_capabilities] || {},
      location_data: @device_info[:location_data] || {},
      network_info: @device_info[:network_info] || {}
    )
  rescue ArgumentError => e
    raise ArgumentError, "Invalid device info: #{e.message}"
  end

  # Validate business rules
  # @param capture_type [CaptureType] capture type
  # @param image_metadata [ImageMetadata] image metadata
  # @param device_info [DeviceInfo] device info
  # @return [String, nil] error message or nil if valid
  def validate_business_rules(capture_type, image_metadata, device_info)
    # Validate image quality requirements
    unless image_metadata.meets_quality_requirements?(capture_type)
      return 'Image does not meet quality requirements for this capture type'
    end

    # Validate file size limits
    unless image_metadata.within_file_size_limit?(capture_type)
      return 'Image file size exceeds maximum allowed for this capture type'
    end

    # Validate device capabilities
    unless device_info.has_camera?
      return 'Device does not have camera capabilities'
    end

    # Validate fraud risk
    if device_info.suspicious_location?
      return 'Suspicious device location detected'
    end

    nil # No validation errors
  end

  # Validate rate limits
  # @return [String, nil] error message or nil if within limits
  def validate_rate_limits
    # This would check against rate limiting service
    # For now, return nil (no rate limit exceeded)
    nil
  end

  # Validate device
  # @return [String, nil] error message or nil if valid
  def validate_device
    # This would validate device registration, permissions, etc.
    nil
  end

  # Validate image data
  # @return [String, nil] error message or nil if valid
  def validate_image
    # This would validate image format, security, etc.
    nil
  end

  # Extract image metadata from image data
  # @return [Hash] metadata parameters
  def extract_image_metadata
    # This would analyze the actual image file or base64 data
    # For now, return placeholder data
    {
      width: @image_data[:width] || 1920,
      height: @image_data[:height] || 1080,
      file_size: @image_data[:file_size] || 1024000,
      format: (@image_data[:format] || :jpeg).to_sym,
      quality_score: @image_data[:quality_score] || 0.8,
      exif_data: @image_data[:exif_data] || {},
      checksum: @image_data[:checksum] || generate_image_checksum
    }
  end

  # Generate image checksum
  # @return [String] SHA-256 checksum
  def generate_image_checksum
    Digest::SHA256.hexdigest("#{@image_data[:url]}:#{@image_data[:data]}:#{Time.current.to_i}")
  end

  # Publish events to event store
  # @param entity [CameraCapture] domain entity
  def publish_events(entity)
    # This would be handled by the event publishing infrastructure
    # For now, just mark events as committed
    entity.mark_events_committed

    # In a real implementation, this would:
    # 1. Store events in event store
    # 2. Publish events to message bus
    # 3. Trigger downstream processes
    # 4. Update read models/projections
  end
end