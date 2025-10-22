# frozen_string_literal: true

# Value Object representing comprehensive image metadata
# Encapsulates all image properties, EXIF data, and processing requirements
class ImageMetadata
  # Image quality thresholds
  QUALITY_THRESHOLDS = {
    excellent: { min_resolution: 3000, min_sharpness: 0.8, max_noise: 0.1 },
    good: { min_resolution: 1920, min_sharpness: 0.6, max_noise: 0.2 },
    acceptable: { min_resolution: 1280, min_sharpness: 0.4, max_noise: 0.3 },
    poor: { min_resolution: 640, min_sharpness: 0.2, max_noise: 0.5 }
  }.freeze

  # Maximum file size by capture type (in bytes)
  MAX_FILE_SIZES = {
    product_photo: 10 * 1024 * 1024,      # 10MB
    barcode_scan: 2 * 1024 * 1024,        # 2MB
    ar_preview: 5 * 1024 * 1024,          # 5MB
    visual_search: 8 * 1024 * 1024,       # 8MB
    review_photo: 15 * 1024 * 1024,       # 15MB
    profile_photo: 5 * 1024 * 1024,       # 5MB
    document_scan: 20 * 1024 * 1024       # 20MB
  }.freeze

  attr_reader :width, :height, :file_size, :format, :quality_score,
              :exif_data, :device_info, :capture_timestamp, :checksum

  # Create new ImageMetadata
  # @param width [Integer] image width in pixels
  # @param height [Integer] image height in pixels
  # @param file_size [Integer] file size in bytes
  # @param format [Symbol] image format (:jpeg, :png, :webp, etc.)
  # @param quality_score [Float] quality score 0.0-1.0
  # @param exif_data [Hash] EXIF metadata
  # @param device_info [Hash] device information
  # @param capture_timestamp [Time] when image was captured
  # @param checksum [String] SHA-256 checksum
  def initialize(
    width:,
    height:,
    file_size:,
    format:,
    quality_score: nil,
    exif_data: {},
    device_info: {},
    capture_timestamp: nil,
    checksum: nil
  )
    @width = width.to_i
    @height = height.to_i
    @file_size = file_size.to_i
    @format = format.to_sym
    @quality_score = quality_score&.to_f
    @exif_data = exif_data.freeze
    @device_info = device_info.freeze
    @capture_timestamp = capture_timestamp || Time.current
    @checksum = checksum.to_s

    validate!
  end

  # Create from file analysis
  # @param file_path [String] path to image file
  # @return [ImageMetadata] metadata object
  def self.from_file(file_path)
    # In a real implementation, this would use libraries like:
    # - MiniMagick for image analysis
    # - Exifr for EXIF data
    # - Digest for checksums

    analysis = analyze_image_file(file_path)

    new(
      width: analysis[:width],
      height: analysis[:height],
      file_size: analysis[:file_size],
      format: analysis[:format],
      quality_score: analysis[:quality_score],
      exif_data: analysis[:exif_data],
      device_info: analysis[:device_info],
      checksum: analysis[:checksum]
    )
  end

  # Create from base64 data
  # @param base64_data [String] base64 encoded image
  # @return [ImageMetadata] metadata object
  def self.from_base64(base64_data)
    # Decode and analyze base64 image data
    analysis = analyze_base64_image(base64_data)

    new(
      width: analysis[:width],
      height: analysis[:height],
      file_size: analysis[:file_size],
      format: analysis[:format],
      quality_score: analysis[:quality_score],
      exif_data: analysis[:exif_data],
      device_info: analysis[:device_info],
      checksum: analysis[:checksum]
    )
  end

  # Get resolution in megapixels
  # @return [Float] resolution in MP
  def megapixels
    (@width * @height).to_f / 1_000_000
  end

  # Get aspect ratio
  # @return [Float] width/height ratio
  def aspect_ratio
    @width.to_f / @height
  end

  # Check if image meets quality requirements for capture type
  # @param capture_type [CaptureType] type of capture
  # @return [Boolean] true if meets requirements
  def meets_quality_requirements?(capture_type)
    threshold = QUALITY_THRESHOLDS[:acceptable] # Minimum acceptable

    # Higher quality requirements for important capture types
    threshold = QUALITY_THRESHOLDS[:good] if capture_type.high_value?

    meets_resolution?(threshold) &&
    meets_sharpness?(threshold) &&
    meets_noise?(threshold) &&
    within_file_size_limit?(capture_type)
  end

  # Check if image is within acceptable file size for capture type
  # @param capture_type [CaptureType] type of capture
  # @return [Boolean] true if within limits
  def within_file_size_limit?(capture_type)
    max_size = MAX_FILE_SIZES[capture_type.type] || MAX_FILE_SIZES[:product_photo]
    @file_size <= max_size
  end

  # Get image orientation based on dimensions
  # @return [Symbol] :landscape, :portrait, or :square
  def orientation
    if @width > @height
      :landscape
    elsif @height > @width
      :portrait
    else
      :square
    end
  end

  # Check if image is high resolution (> 4K)
  # @return [Boolean] true if high resolution
  def high_resolution?
    @width >= 3840 || @height >= 2160
  end

  # Get file size in human-readable format
  # @return [String] formatted file size
  def human_file_size
    units = %w[B KB MB GB]
    size = @file_size.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    format('%.1f %s', size, units[unit_index])
  end

  # Get estimated compression ratio
  # @return [Float] compression ratio
  def compression_ratio
    # Estimate based on quality and format
    case @format
    when :jpeg
      quality_score ? 1.0 / (quality_score * 0.8 + 0.2) : 2.5
    when :png
      1.2 # PNG typically has lower compression
    else
      2.0 # Default estimate
    end
  end

  # Equality comparison
  # @param other [ImageMetadata] other metadata to compare
  # @return [Boolean] true if equal
  def ==(other)
    return false unless other.is_a?(ImageMetadata)

    @width == other.width &&
    @height == other.height &&
    @file_size == other.file_size &&
    @format == other.format &&
    @checksum == other.checksum
  end

  # Hash for use in collections
  # @return [Integer] hash value
  def hash
    [@width, @height, @file_size, @format, @checksum].hash
  end

  # Convert to hash for serialization
  # @return [Hash] serializable hash
  def to_hash
    {
      width: @width,
      height: @height,
      file_size: @file_size,
      format: @format,
      quality_score: @quality_score,
      megapixels: megapixels,
      aspect_ratio: aspect_ratio,
      orientation: orientation,
      exif_data: @exif_data,
      device_info: @device_info,
      capture_timestamp: @capture_timestamp,
      checksum: @checksum
    }
  end

  private

  # Validate metadata integrity
  def validate!
    raise ArgumentError, 'Width must be positive' if @width <= 0
    raise ArgumentError, 'Height must be positive' if @height <= 0
    raise ArgumentError, 'File size must be positive' if @file_size <= 0
    raise ArgumentError, 'Invalid format' unless valid_format?
    raise ArgumentError, 'Invalid quality score' if @quality_score && (@quality_score < 0 || @quality_score > 1)
  end

  # Check if format is supported
  # @return [Boolean] true if supported
  def valid_format?
    [:jpeg, :jpg, :png, :webp, :heic, :tiff].include?(@format)
  end

  # Check if meets minimum resolution requirement
  # @param threshold [Hash] quality threshold
  # @return [Boolean] true if meets requirement
  def meets_resolution?(threshold)
    @width >= threshold[:min_resolution] && @height >= threshold[:min_resolution]
  end

  # Check if meets sharpness requirement
  # @param threshold [Hash] quality threshold
  # @return [Boolean] true if meets requirement
  def meets_sharpness?(threshold)
    return true unless @quality_score # Assume good if not measured
    @quality_score >= threshold[:min_sharpness]
  end

  # Check if meets noise requirement
  # @param threshold [Hash] quality threshold
  # @return [Boolean] true if meets requirement
  def meets_noise?(threshold)
    return true unless @quality_score # Assume good if not measured
    @quality_score <= threshold[:max_noise]
  end

  # Analyze image file (placeholder implementation)
  # @param file_path [String] path to file
  # @return [Hash] analysis results
  def self.analyze_image_file(file_path)
    # This would use actual image analysis libraries
    {
      width: 1920,
      height: 1080,
      file_size: File.size(file_path),
      format: :jpeg,
      quality_score: 0.8,
      exif_data: {},
      device_info: {},
      checksum: Digest::SHA256.file(file_path).hexdigest
    }
  end

  # Analyze base64 image (placeholder implementation)
  # @param base64_data [String] base64 image data
  # @return [Hash] analysis results
  def self.analyze_base64_image(base64_data)
    # This would decode and analyze base64 image
    {
      width: 1920,
      height: 1080,
      file_size: base64_data.length * 0.75, # Approximate
      format: :jpeg,
      quality_score: 0.8,
      exif_data: {},
      device_info: {},
      checksum: Digest::SHA256.hexdigest(base64_data)
    }
  end
end