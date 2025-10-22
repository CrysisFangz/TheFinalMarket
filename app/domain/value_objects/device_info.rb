# frozen_string_literal: true

# Value Object representing mobile device information
# Provides comprehensive device fingerprinting and validation
class DeviceInfo
  # Device types with capabilities
  DEVICE_TYPES = {
    smartphone: { has_camera: true, has_ar: true, typical_quality: :high },
    tablet: { has_camera: true, has_ar: false, typical_quality: :medium },
    smart_glasses: { has_camera: true, has_ar: true, typical_quality: :premium },
    drone: { has_camera: true, has_ar: false, typical_quality: :ultra },
    webcam: { has_camera: true, has_ar: false, typical_quality: :low }
  }.freeze

  # Operating systems with capabilities
  OPERATING_SYSTEMS = {
    ios: { ar_kit: true, camera_api: :advanced, security: :high },
    android: { ar_core: true, camera_api: :advanced, security: :medium },
    unknown: { ar_kit: false, camera_api: :basic, security: :low }
  }.freeze

  attr_reader :device_id, :device_type, :operating_system, :app_version,
              :camera_capabilities, :location_data, :network_info

  # Create new DeviceInfo
  # @param device_id [String] unique device identifier
  # @param device_type [Symbol] type of device
  # @param operating_system [Symbol] OS type
  # @param app_version [String] application version
  # @param camera_capabilities [Hash] camera specifications
  # @param location_data [Hash] location information
  # @param network_info [Hash] network details
  def initialize(
    device_id:,
    device_type: :smartphone,
    operating_system: :unknown,
    app_version: nil,
    camera_capabilities: {},
    location_data: {},
    network_info: {}
  )
    @device_id = device_id.to_s
    @device_type = device_type.to_sym
    @operating_system = operating_system.to_sym
    @app_version = app_version.to_s
    @camera_capabilities = camera_capabilities.freeze
    @location_data = location_data.freeze
    @network_info = network_info.freeze

    validate!
  end

  # Create from mobile device model
  # @param mobile_device [MobileDevice] Rails model
  # @return [DeviceInfo] device info object
  def self.from_mobile_device(mobile_device)
    new(
      device_id: mobile_device.device_id,
      device_type: mobile_device.device_type.to_sym,
      operating_system: mobile_device.operating_system.to_sym,
      app_version: mobile_device.app_version,
      camera_capabilities: extract_camera_capabilities(mobile_device),
      location_data: extract_location_data(mobile_device),
      network_info: extract_network_info(mobile_device)
    )
  end

  # Create from HTTP request headers
  # @param headers [Hash] HTTP headers
  # @return [DeviceInfo] device info object
  def self.from_headers(headers)
    new(
      device_id: extract_device_id(headers),
      device_type: extract_device_type(headers),
      operating_system: extract_os(headers),
      app_version: extract_app_version(headers),
      camera_capabilities: extract_camera_from_headers(headers),
      location_data: extract_location_from_headers(headers),
      network_info: extract_network_from_headers(headers)
    )
  end

  # Get device capabilities for this device type
  # @return [Hash] device capabilities
  def capabilities
    DEVICE_TYPES[@device_type] || DEVICE_TYPES[:smartphone]
  end

  # Get OS capabilities
  # @return [Hash] OS capabilities
  def os_capabilities
    OPERATING_SYSTEMS[@operating_system] || OPERATING_SYSTEMS[:unknown]
  end

  # Check if device supports AR
  # @return [Boolean] true if AR supported
  def supports_ar?
    capabilities[:has_ar] && os_capabilities[:ar_kit]
  end

  # Check if device has camera
  # @return [Boolean] true if camera available
  def has_camera?
    capabilities[:has_camera]
  end

  # Get expected image quality for this device
  # @return [Symbol] quality level
  def expected_quality
    capabilities[:typical_quality]
  end

  # Check if device is considered trusted
  # @return [Boolean] true if trusted
  def trusted_device?
    @device_id.present? &&
    @app_version.present? &&
    os_capabilities[:security] == :high
  end

  # Get device fingerprint for fraud detection
  # @return [String] device fingerprint hash
  def fingerprint
    Digest::SHA256.hexdigest(
      [
        @device_id,
        @device_type,
        @operating_system,
        @app_version,
        @camera_capabilities.to_s,
        @location_data.to_s
      ].join('|')
    )
  end

  # Get geographic region based on location data
  # @return [Symbol] geographic region
  def geographic_region
    return :unknown unless @location_data[:country_code]

    case @location_data[:country_code].upcase
    when 'US', 'CA', 'MX' then :north_america
    when 'GB', 'DE', 'FR', 'IT', 'ES' then :europe
    when 'JP', 'KR', 'CN', 'IN' then :asia_pacific
    when 'BR', 'AR', 'CL' then :south_america
    when 'AU', 'NZ' then :oceania
    when 'ZA', 'EG', 'NG' then :africa
    else :unknown
    end
  end

  # Check if device location is suspicious
  # @return [Boolean] true if location seems suspicious
  def suspicious_location?
    # Check for impossible location changes, VPN indicators, etc.
    @location_data[:vpn_detected] ||
    @location_data[:proxy_detected] ||
    location_changed_too_quickly?
  end

  # Get network quality score (0.0-1.0)
  # @return [Float] network quality score
  def network_quality_score
    return 0.5 unless @network_info[:connection_type]

    case @network_info[:connection_type].to_sym
    when :wifi then 0.9
    when :cellular_5g then 0.8
    when :cellular_4g then 0.7
    when :cellular_3g then 0.5
    when :cellular_2g then 0.3
    else 0.5
    end
  end

  # Get device age category
  # @return [Symbol] age category
  def age_category
    return :unknown unless @app_version

    # This would parse version dates and compare to current
    # For now, return based on version string patterns
    if @app_version.include?('beta') || @app_version.include?('alpha')
      :prerelease
    else
      :production
    end
  end

  # Equality comparison
  # @param other [DeviceInfo] other device info
  # @return [Boolean] true if equal
  def ==(other)
    return false unless other.is_a?(DeviceInfo)

    @device_id == other.device_id &&
    @device_type == other.device_type &&
    @operating_system == other.operating_system
  end

  # Hash for use in collections
  # @return [Integer] hash value
  def hash
    [@device_id, @device_type, @operating_system].hash
  end

  # Convert to hash for serialization
  # @return [Hash] serializable hash
  def to_hash
    {
      device_id: @device_id,
      device_type: @device_type,
      operating_system: @operating_system,
      app_version: @app_version,
      capabilities: capabilities,
      os_capabilities: os_capabilities,
      fingerprint: fingerprint,
      geographic_region: geographic_region,
      network_quality_score: network_quality_score,
      age_category: age_category
    }
  end

  private

  # Validate device info integrity
  def validate!
    raise ArgumentError, 'Device ID is required' if @device_id.blank?
    raise ArgumentError, 'Invalid device type' unless valid_device_type?
    raise ArgumentError, 'Invalid operating system' unless valid_os?
  end

  # Check if device type is valid
  # @return [Boolean] true if valid
  def valid_device_type?
    DEVICE_TYPES.key?(@device_type)
  end

  # Check if OS is valid
  # @return [Boolean] true if valid
  def valid_os?
    OPERATING_SYSTEMS.key?(@operating_system)
  end

  # Check if location changed impossibly fast
  # @return [Boolean] true if suspicious
  def location_changed_too_quickly?
    return false unless @location_data[:previous_location]

    # This would compare timestamps and distance
    # For now, return false (would need previous capture data)
    false
  end

  # Extract device ID from headers (placeholder)
  # @param headers [Hash] HTTP headers
  # @return [String] device ID
  def self.extract_device_id(headers)
    headers['X-Device-ID'] || headers['HTTP_X_DEVICE_ID'] || 'unknown'
  end

  # Extract device type from headers (placeholder)
  # @param headers [Hash] HTTP headers
  # @return [Symbol] device type
  def self.extract_device_type(headers)
    user_agent = headers['User-Agent'] || ''
    if user_agent.include?('Mobile')
      :smartphone
    elsif user_agent.include?('Tablet')
      :tablet
    else
      :smartphone
    end
  end

  # Extract OS from headers (placeholder)
  # @param headers [Hash] HTTP headers
  # @return [Symbol] operating system
  def self.extract_os(headers)
    user_agent = headers['User-Agent'] || ''
    if user_agent.include?('iOS') || user_agent.include?('iPhone') || user_agent.include?('iPad')
      :ios
    elsif user_agent.include?('Android')
      :android
    else
      :unknown
    end
  end

  # Extract app version from headers (placeholder)
  # @param headers [Hash] HTTP headers
  # @return [String] app version
  def self.extract_app_version(headers)
    headers['X-App-Version'] || headers['HTTP_X_APP_VERSION'] || '1.0.0'
  end

  # Extract camera capabilities from mobile device model (placeholder)
  # @param mobile_device [MobileDevice] Rails model
  # @return [Hash] camera capabilities
  def self.extract_camera_capabilities(mobile_device)
    {
      megapixels: mobile_device.camera_megapixels || 12,
      has_flash: mobile_device.has_flash || true,
      supports_hdr: mobile_device.supports_hdr || true,
      max_resolution: mobile_device.max_resolution || '4032x3024'
    }
  end

  # Extract location data from mobile device model (placeholder)
  # @param mobile_device [MobileDevice] Rails model
  # @return [Hash] location data
  def self.extract_location_data(mobile_device)
    {
      country_code: mobile_device.country_code,
      region: mobile_device.region,
      timezone: mobile_device.timezone,
      coordinates: mobile_device.last_coordinates
    }
  end

  # Extract network info from mobile device model (placeholder)
  # @param mobile_device [MobileDevice] Rails model
  # @return [Hash] network info
  def self.extract_network_info(mobile_device)
    {
      connection_type: mobile_device.connection_type&.to_sym,
      ip_address: mobile_device.ip_address,
      vpn_detected: mobile_device.vpn_detected || false,
      proxy_detected: mobile_device.proxy_detected || false
    }
  end

  # Extract camera info from headers (placeholder)
  # @param headers [Hash] HTTP headers
  # @return [Hash] camera capabilities
  def self.extract_camera_from_headers(headers)
    {
      megapixels: headers['X-Camera-Megapixels']&.to_i || 12,
      supports_hdr: headers['X-Camera-HDR'] == 'true'
    }
  end

  # Extract location from headers (placeholder)
  # @param headers [Hash] HTTP headers
  # @return [Hash] location data
  def self.extract_location_from_headers(headers)
    {
      country_code: headers['X-Country-Code'],
      timezone: headers['X-Timezone']
    }
  end

  # Extract network info from headers (placeholder)
  # @param headers [Hash] HTTP headers
  # @return [Hash] network info
  def self.extract_network_from_headers(headers)
    {
      connection_type: headers['X-Connection-Type']&.to_sym || :wifi,
      ip_address: headers['X-Real-IP'] || headers['X-Forwarded-For']
    }
  end
end