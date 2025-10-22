# frozen_string_literal: true

require_relative '../domain/value_objects/event_hash'
require_relative '../domain/value_objects/event_data'

# Service object for recording blockchain provenance events
# Handles all business logic for event creation and validation
class ProvenanceEventService
  # Error class for event recording failures
  class EventError < StandardError; end

  # Execute event recording
  # @param provenance [BlockchainProvenance] provenance record
  # @param event_type [Symbol] type of event
  # @param description [String] event description
  # @param data [Hash] event data
  # @return [ProvenanceEvent] created event
  # @raise [EventError] if event recording fails
  def self.execute!(provenance:, event_type:, description:, data: {})
    new(provenance, event_type, description, data).execute!
  end

  # Initialize service
  # @param provenance [BlockchainProvenance] provenance record
  # @param event_type [Symbol] type of event
  # @param description [String] event description
  # @param data [Hash] event data
  def initialize(provenance, event_type, description, data = {})
    @provenance = provenance
    @event_type = event_type.to_sym
    @description = description.to_s
    @data = data.dup.freeze
    @errors = []
  end

  # Execute the event recording process
  # @return [ProvenanceEvent] created event
  # @raise [EventError] if event recording fails
  def execute!
    validate_inputs
    create_event_record
    write_to_blockchain

    @event
  rescue ActiveRecord::RecordInvalid => e
    @errors << e.message
    raise EventError, "Failed to record event: #{@errors.join(', ')}"
  rescue StandardError => e
    @errors << e.message
    raise EventError, "Unexpected error during event recording: #{@errors.join(', ')}"
  end

  private

  # Validate input parameters
  # @raise [EventError] if validation fails
  def validate_inputs
    @errors.clear

    @errors << 'Provenance is required' if @provenance.nil?
    @errors << 'Event type is required' if @event_type.blank?
    @errors << 'Description is required' if @description.blank?
    @errors << 'Event type must be a symbol' unless @event_type.is_a?(Symbol)
    @errors << 'Invalid event type' unless valid_event_type?

    validate_event_data
    validate_event_sequence

    raise EventError, "Validation failed: #{@errors.join(', ')}" unless @errors.empty?
  end

  # Validate event type is supported
  # @return [Boolean] true if valid event type
  def valid_event_type?
    supported_events = [
      :created, :manufactured, :quality_checked, :shipped,
      :ownership_transferred, :certified, :inspected,
      :stored, :retrieved, :damaged, :repaired
    ]

    supported_events.include?(@event_type)
  end

  # Validate event data structure and content
  def validate_event_data
    # Validate required fields based on event type
    case @event_type
    when :manufactured
      validate_manufacturing_data
    when :quality_checked
      validate_quality_check_data
    when :shipped
      validate_shipping_data
    when :ownership_transferred
      validate_ownership_data
    when :certified
      validate_certification_data
    end

    # Validate timestamp if provided
    if @data[:timestamp] && !valid_timestamp?(@data[:timestamp])
      @errors << 'Invalid timestamp format'
    end

    # Validate location data if provided
    if @data[:location] && !valid_location?(@data[:location])
      @errors << 'Invalid location format'
    end
  end

  # Validate manufacturing event data
  def validate_manufacturing_data
    required_fields = %i[manufacturer batch_number]
    missing_fields = required_fields.select { |field| @data[field].blank? }

    @errors << "Missing manufacturing data: #{missing_fields.join(', ')}" unless missing_fields.empty?
  end

  # Validate quality check event data
  def validate_quality_check_data
    required_fields = %i[inspector passed]
    missing_fields = required_fields.select { |field| @data[field].blank? }

    @errors << "Missing quality check data: #{missing_fields.join(', ')}" unless missing_fields.empty?

    if @data[:passed].present? && !valid_boolean?(@data[:passed])
      @errors << 'Quality check result must be boolean'
    end
  end

  # Validate shipping event data
  def validate_shipping_data
    required_fields = %i[carrier tracking_number from to]
    missing_fields = required_fields.select { |field| @data[field].blank? }

    @errors << "Missing shipping data: #{missing_fields.join(', ')}" unless missing_fields.empty?
  end

  # Validate ownership transfer event data
  def validate_ownership_data
    required_fields = %i[from_owner to_owner]
    missing_fields = required_fields.select { |field| @data[field].blank? }

    @errors << "Missing ownership data: #{missing_fields.join(', ')}" unless missing_fields.empty?
  end

  # Validate certification event data
  def validate_certification_data
    required_fields = %i[certification_type certifier certificate_number]
    missing_fields = required_fields.select { |field| @data[field].blank? }

    @errors << "Missing certification data: #{missing_fields.join(', ')}" unless missing_fields.empty?
  end

  # Validate event sequence and business rules
  def validate_event_sequence
    # Cannot record events for unverified provenance (except creation)
    if @event_type != :created && !@provenance.verified?
      @errors << 'Cannot record events for unverified provenance'
    end

    # Validate event ordering for business logic
    validate_business_logic_rules
  end

  # Validate business logic rules for event sequences
  def validate_business_logic_rules
    case @event_type
    when :ownership_transferred
      validate_ownership_transfer_rules
    when :quality_checked
      validate_quality_check_rules
    end
  end

  # Validate ownership transfer business rules
  def validate_ownership_transfer_rules
    last_event = @provenance.provenance_events.order(occurred_at: :desc).first

    # Cannot transfer ownership of failed quality check items
    if last_event&.event_type == 'quality_checked' &&
       last_event.event_data.get('passed') == false
      @errors << 'Cannot transfer ownership of failed quality check item'
    end
  end

  # Validate quality check business rules
  def validate_quality_check_rules
    # Must have been manufactured before quality check
    manufacturing_event = @provenance.provenance_events.find_by(event_type: :manufactured)
    if manufacturing_event.nil?
      @errors << 'Cannot perform quality check before manufacturing'
    end
  end

  # Validate timestamp format
  # @param timestamp [Object] timestamp to validate
  # @return [Boolean] true if valid
  def valid_timestamp?(timestamp)
    timestamp.is_a?(Time) || timestamp.is_a?(String) && Time.parse(timestamp)
  rescue ArgumentError
    false
  end

  # Validate location format (basic validation)
  # @param location [Object] location to validate
  # @return [Boolean] true if valid
  def valid_location?(location)
    location.is_a?(String) && location.length > 0 && location.length <= 255
  end

  # Validate boolean value
  # @param value [Object] value to validate
  # @return [Boolean] true if valid boolean
  def valid_boolean?(value)
    [true, false].include?(value)
  end

  # Create the event record
  def create_event_record
    event_data = EventData.new(
      @data.merge(
        event_type: @event_type,
        description: @description,
        provenance_id: @provenance.id,
        timestamp: Time.current
      ),
      Time.current,
      { source: 'ProvenanceEventService' }
    )

    @event = @provenance.provenance_events.create!(
      event_type: @event_type,
      description: @description,
      event_data: event_data,
      occurred_at: Time.current,
      blockchain_hash: generate_event_hash
    )
  rescue ActiveRecord::RecordInvalid => e
    @errors << "Database error: #{e.message}"
    raise EventError, "Failed to save event record: #{@errors.join(', ')}"
  end

  # Write event to blockchain
  def write_to_blockchain
    BlockchainService.write_event(@event)
  rescue BlockchainService::BlockchainError => e
    # Log error but don't fail the event recording
    Rails.logger.error("Blockchain write failed for event: #{e.message}")
    @errors << "Blockchain write failed: #{e.message}"
  end

  # Generate event hash for blockchain
  # @return [EventHash] generated hash
  def generate_event_hash
    data_for_hash = {
      provenance_id: @provenance.id,
      event_type: @event_type,
      description: @description,
      data: @data,
      timestamp: Time.current.to_i
    }

    EventHash.from_data(data_for_hash)
  end
end