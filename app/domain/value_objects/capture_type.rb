# frozen_string_literal: true

# Value Object representing the type of camera capture operation
# Provides strong typing and domain-specific behavior for capture classification
class CaptureType
  # Supported capture types with their metadata
  CAPTURE_TYPES = {
    product_photo: {
      id: 0,
      description: 'Product photography for marketplace listings',
      requires_processing: true,
      storage_tier: :hot,
      retention_days: 2555, # 7 years for legal compliance
      fraud_risk: :high
    },
    barcode_scan: {
      id: 1,
      description: 'Barcode scanning for product identification',
      requires_processing: false,
      storage_tier: :warm,
      retention_days: 90,
      fraud_risk: :low
    },
    ar_preview: {
      id: 2,
      description: 'Augmented reality preview capture',
      requires_processing: true,
      storage_tier: :hot,
      retention_days: 30,
      fraud_risk: :medium
    },
    visual_search: {
      id: 3,
      description: 'Visual search query image',
      requires_processing: true,
      storage_tier: :hot,
      retention_days: 7,
      fraud_risk: :medium
    },
    review_photo: {
      id: 4,
      description: 'Product review image submission',
      requires_processing: true,
      storage_tier: :cold,
      retention_days: 365,
      fraud_risk: :high
    },
    profile_photo: {
      id: 5,
      description: 'User profile image update',
      requires_processing: true,
      storage_tier: :hot,
      retention_days: 365,
      fraud_risk: :medium
    },
    document_scan: {
      id: 6,
      description: 'Document scanning for verification',
      requires_processing: true,
      storage_tier: :cold,
      retention_days: 2555, # 7 years legal requirement
      fraud_risk: :critical
    }
  }.freeze

  attr_reader :type, :metadata

  # Create a new CaptureType
  # @param type [Symbol] the capture type identifier
  # @raise [ArgumentError] if the type is not supported
  def initialize(type)
    @type = type.to_sym
    @metadata = CAPTURE_TYPES[@type]

    raise ArgumentError, "Unsupported capture type: #{@type}" unless @metadata
  end

  # Create from integer ID
  # @param id [Integer] numeric identifier
  # @return [CaptureType] new capture type
  def self.from_id(id)
    type_entry = CAPTURE_TYPES.find { |_, metadata| metadata[:id] == id }
    raise ArgumentError, "Invalid capture type ID: #{id}" unless type_entry

    new(type_entry[0])
  end

  # Create from symbol name
  # @param type [Symbol] capture type name
  # @return [CaptureType] new capture type
  def self.from_symbol(type)
    new(type)
  end

  # Get numeric ID for this capture type
  # @return [Integer] numeric identifier
  def to_i
    @metadata[:id]
  end

  # Get description for this capture type
  # @return [String] human-readable description
  def description
    @metadata[:description]
  end

  # Check if this capture type requires image processing
  # @return [Boolean] true if processing is required
  def requires_processing?
    @metadata[:requires_processing]
  end

  # Get storage tier for this capture type
  # @return [Symbol] storage tier identifier
  def storage_tier
    @metadata[:storage_tier]
  end

  # Get retention period in days
  # @return [Integer] days to retain the capture
  def retention_days
    @metadata[:retention_days]
  end

  # Get fraud risk level for this capture type
  # @return [Symbol] fraud risk classification
  def fraud_risk
    @metadata[:fraud_risk]
  end

  # Check if this is a high-value capture type requiring enhanced validation
  # @return [Boolean] true if high-value
  def high_value?
    [:high, :critical].include?(fraud_risk)
  end

  # Get processing priority (lower number = higher priority)
  # @return [Integer] priority level
  def processing_priority
    case fraud_risk
    when :critical then 1
    when :high then 2
    when :medium then 3
    when :low then 4
    else 5
    end
  end

  # Get all supported capture types
  # @return [Array<Symbol>] array of supported types
  def self.all_types
    CAPTURE_TYPES.keys
  end

  # Get types requiring legal compliance retention
  # @return [Array<Symbol>] types with 7-year retention
  def self.legal_compliance_types
    CAPTURE_TYPES.select { |_, meta| meta[:retention_days] >= 2555 }.keys
  end

  # Equality comparison
  # @param other [CaptureType] other type to compare
  # @return [Boolean] true if equal
  def ==(other)
    return false unless other.is_a?(CaptureType)
    @type == other.type
  end

  # Hash for use in collections
  # @return [Integer] hash value
  def hash
    @type.hash
  end

  # Convert to string for debugging
  # @return [String] string representation
  def inspect
    "#<CaptureType:#{@type}>"
  end

  # Convert to string
  # @return [String] string representation
  def to_s
    @type.to_s
  end
end