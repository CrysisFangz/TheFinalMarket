# frozen_string_literal: true

require_relative '../domain/value_objects/provenance_id'
require_relative '../domain/value_objects/event_hash'

# Service object for creating blockchain provenance records
# Encapsulates all business logic for provenance creation
class ProvenanceCreationService
  # Error class for creation failures
  class CreationError < StandardError; end

  # Execute provenance creation
  # @param product [Product] the product to create provenance for
  # @param origin_data [Hash] origin data for the product
  # @return [BlockchainProvenance] created provenance record
  # @raise [CreationError] if creation fails
  def self.execute!(product:, origin_data: {})
    new(product, origin_data).execute!
  end

  # Initialize service
  # @param product [Product] the product
  # @param origin_data [Hash] origin data
  def initialize(product, origin_data = {})
    @product = product
    @origin_data = origin_data.dup.freeze
    @errors = []
  end

  # Execute the creation process
  # @return [BlockchainProvenance] created provenance record
  # @raise [CreationError] if creation fails
  def execute!
    validate_inputs
    create_provenance_record
    record_creation_event
    write_to_blockchain

    @provenance
  rescue ActiveRecord::RecordInvalid => e
    @errors << e.message
    raise CreationError, "Failed to create provenance: #{@errors.join(', ')}"
  rescue StandardError => e
    @errors << e.message
    raise CreationError, "Unexpected error during provenance creation: #{@errors.join(', ')}"
  end

  private

  # Validate input parameters
  # @raise [CreationError] if validation fails
  def validate_inputs
    @errors.clear

    @errors << 'Product is required' if @product.nil?
    @errors << 'Product must be persisted' if @product&.new_record?
    @errors << 'Origin data must be a hash' unless @origin_data.is_a?(Hash)

    validate_origin_data

    raise CreationError, "Validation failed: #{@errors.join(', ')}" unless @errors.empty?
  end

  # Validate origin data structure
  def validate_origin_data
    required_fields = %w[origin_country manufacturer_name batch_id]
    missing_fields = required_fields.select { |field| @origin_data[field].blank? }

    @errors << "Missing required origin data fields: #{missing_fields.join(', ')}" unless missing_fields.empty?

    # Validate data types and formats
    if @origin_data['origin_country'] && !valid_country_code?(@origin_data['origin_country'])
      @errors << 'Invalid origin country code format'
    end

    if @origin_data['batch_id'] && !valid_batch_id?(@origin_data['batch_id'])
      @errors << 'Invalid batch ID format'
    end
  end

  # Validate country code format (ISO 3166-1 alpha-2)
  # @param country_code [String] country code to validate
  # @return [Boolean] true if valid
  def valid_country_code?(country_code)
    country_code.is_a?(String) && country_code.match?(/^[A-Z]{2}$/)
  end

  # Validate batch ID format
  # @param batch_id [String] batch ID to validate
  # @return [Boolean] true if valid
  def valid_batch_id?(batch_id)
    batch_id.is_a?(String) && batch_id.length.between?(3, 50)
  end

  # Create the provenance record
  def create_provenance_record
    @provenance = BlockchainProvenance.create!(
      product: @product,
      blockchain_id: generate_blockchain_id,
      blockchain: default_blockchain,
      origin_data: @origin_data,
      verified: false
    )
  rescue ActiveRecord::RecordInvalid => e
    @errors << "Database error: #{e.message}"
    raise CreationError, "Failed to save provenance record: #{@errors.join(', ')}"
  end

  # Record the creation event
  def record_creation_event
    event_data = EventData.new(
      {
        action: 'provenance_created',
        product_id: @product.id,
        product_name: @product.name,
        origin_data: @origin_data,
        timestamp: Time.current
      },
      Time.current,
      { source: 'ProvenanceCreationService' }
    )

    @provenance.provenance_events.create!(
      event_type: :created,
      description: 'Product registered on blockchain',
      event_data: event_data,
      occurred_at: Time.current,
      blockchain_hash: generate_event_hash
    )
  rescue ActiveRecord::RecordInvalid => e
    @errors << "Failed to record creation event: #{e.message}"
    raise CreationError, "Failed to record creation event: #{@errors.join(', ')}"
  end

  # Write provenance to blockchain
  def write_to_blockchain
    BlockchainService.write_provenance(@provenance)
  rescue BlockchainService::BlockchainError => e
    # Log error but don't fail the creation
    Rails.logger.error("Blockchain write failed: #{e.message}")
    @errors << "Blockchain write failed: #{e.message}"
  end

  # Generate unique blockchain ID
  # @return [ProvenanceId] generated ID
  def generate_blockchain_id
    ProvenanceId.generate
  end

  # Generate event hash
  # @return [EventHash] generated hash
  def generate_event_hash
    EventHash.from_data("creation:#{@product.id}:#{Time.current.to_i}")
  end

  # Get default blockchain for provenance
  # @return [Symbol] default blockchain
  def default_blockchain
    # Use environment variable or default to polygon
    ENV.fetch('DEFAULT_BLOCKCHAIN', 'polygon').to_sym
  end

  # Check if product already has provenance
  # @return [Boolean] true if provenance exists
  def provenance_exists?
    BlockchainProvenance.exists?(product_id: @product.id)
  end
end