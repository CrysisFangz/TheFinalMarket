# frozen_string_literal: true

# Service object for verifying blockchain provenance records
# Handles blockchain verification with comprehensive validation
class ProvenanceVerificationService
  # Error class for verification failures
  class VerificationError < StandardError; end

  # Execute provenance verification
  # @param provenance [BlockchainProvenance] provenance to verify
  # @return [Hash] verification result
  # @raise [VerificationError] if verification fails
  def self.execute!(provenance:)
    new(provenance).execute!
  end

  # Initialize service
  # @param provenance [BlockchainProvenance] provenance to verify
  def initialize(provenance)
    @provenance = provenance
    @errors = []
  end

  # Execute the verification process
  # @return [Hash] verification result
  # @raise [VerificationError] if verification fails
  def execute!
    validate_inputs
    fetch_blockchain_data
    perform_verification
    update_verification_status

    verification_result
  rescue StandardError => e
    @errors << e.message
    raise VerificationError, "Verification failed: #{@errors.join(', ')}"
  end

  private

  # Validate input parameters
  # @raise [VerificationError] if validation fails
  def validate_inputs
    @errors.clear

    @errors << 'Provenance is required' if @provenance.nil?
    @errors << 'Provenance must be persisted' if @provenance&.new_record?
    @errors << 'Blockchain ID is required' if @provenance&.blockchain_id.blank?

    raise VerificationError, "Validation failed: #{@errors.join(', ')}" unless @errors.empty?
  end

  # Fetch blockchain data for verification
  def fetch_blockchain_data
    @blockchain_data = BlockchainService.fetch_provenance_data(@provenance)
  rescue BlockchainService::BlockchainError => e
    @errors << "Failed to fetch blockchain data: #{e.message}"
    raise VerificationError, "Blockchain fetch failed: #{@errors.join(', ')}"
  end

  # Perform comprehensive verification
  def perform_verification
    @verification_result = {
      verified: false,
      blockchain_verified: verify_blockchain_integrity,
      data_integrity_verified: verify_data_integrity,
      event_chain_verified: verify_event_chain,
      timestamp_verified: verify_timestamps,
      hash_verified: verify_hashes,
      errors: [],
      warnings: []
    }

    # Overall verification status
    @verification_result[:verified] = @verification_result.values_at(
      :blockchain_verified,
      :data_integrity_verified,
      :event_chain_verified,
      :timestamp_verified,
      :hash_verified
    ).all?(true)

    # Add warnings for non-critical issues
    add_verification_warnings

    unless @verification_result[:verified]
      @errors << 'Verification failed one or more checks'
    end
  end

  # Verify blockchain integrity
  # @return [Boolean] true if blockchain data is valid
  def verify_blockchain_integrity
    return false if @blockchain_data.nil?

    # Verify blockchain reports as verified
    blockchain_verified = @blockchain_data[:verified] == true

    # Verify blockchain hash exists
    hash_exists = @blockchain_data[:hash].present? &&
                  @blockchain_data[:hash] != '0x0000000000000000000000000000000000000000000000000000000000000000'

    # Verify block number exists
    block_exists = @blockchain_data[:block_number].present? && @blockchain_data[:block_number] > 0

    blockchain_verified && hash_exists && block_exists
  rescue StandardError => e
    @errors << "Blockchain integrity check failed: #{e.message}"
    false
  end

  # Verify data integrity using cryptographic hashes
  # @return [Boolean] true if data integrity is verified
  def verify_data_integrity
    return false if @blockchain_data.nil?

    # Calculate expected hash from local data
    expected_hash = calculate_local_hash

    # Compare with blockchain hash
    actual_hash = normalize_hash(@blockchain_data[:hash])

    if expected_hash == actual_hash
      true
    else
      @errors << "Data integrity check failed: hash mismatch (expected: #{expected_hash}, actual: #{actual_hash})"
      false
    end
  rescue StandardError => e
    @errors << "Data integrity verification failed: #{e.message}"
    false
  end

  # Verify event chain integrity
  # @return [Boolean] true if event chain is valid
  def verify_event_chain
    return false if @blockchain_data.nil?

    expected_events = @blockchain_data[:events] || 0
    actual_events = @provenance.provenance_events.count

    if expected_events == actual_events
      # Verify event hash chain
      verify_event_hash_chain
    else
      @errors << "Event count mismatch: blockchain shows #{expected_events}, local shows #{actual_events}"
      false
    end
  rescue StandardError => e
    @errors << "Event chain verification failed: #{e.message}"
    false
  end

  # Verify event hash chain integrity
  # @return [Boolean] true if event chain is valid
  def verify_event_hash_chain
    events = @provenance.provenance_events.order(occurred_at: :asc)
    return true if events.empty?

    # Verify each event's hash matches calculated hash
    events.each_with_index do |event, index|
      expected_hash = calculate_event_hash(event, index)
      actual_hash = normalize_hash(event.blockchain_hash)

      unless expected_hash == actual_hash
        @errors << "Event hash mismatch at event #{index + 1}"
        return false
      end
    end

    true
  rescue StandardError => e
    @errors << "Event hash chain verification failed: #{e.message}"
    false
  end

  # Verify timestamp validity and ordering
  # @return [Boolean] true if timestamps are valid
  def verify_timestamps
    return false if @blockchain_data.nil?

    blockchain_timestamp = @blockchain_data[:timestamp]
    local_timestamp = @provenance.created_at

    # Blockchain timestamp should be close to creation time (within 5 minutes)
    time_difference = (blockchain_timestamp - local_timestamp).abs

    if time_difference <= 5.minutes
      # Verify event timestamp ordering
      verify_event_timestamp_ordering
    else
      @errors << "Timestamp mismatch: difference of #{time_difference} seconds exceeds threshold"
      false
    end
  rescue StandardError => e
    @errors << "Timestamp verification failed: #{e.message}"
    false
  end

  # Verify event timestamp ordering
  # @return [Boolean] true if event timestamps are properly ordered
  def verify_event_timestamp_ordering
    events = @provenance.provenance_events.order(occurred_at: :asc)

    events.each_cons(2) do |prev_event, current_event|
      if current_event.occurred_at < prev_event.occurred_at
        @errors << "Event timestamp ordering violation between events #{prev_event.id} and #{current_event.id}"
        return false
      end
    end

    true
  end

  # Verify all hashes are valid and consistent
  # @return [Boolean] true if hashes are valid
  def verify_hashes
    return false if @blockchain_data.nil?

    # Verify provenance hash format
    unless valid_hash_format?(@blockchain_data[:hash])
      @errors << 'Invalid blockchain hash format'
      return false
    end

    # Verify all event hashes have valid format
    @provenance.provenance_events.each do |event|
      unless valid_hash_format?(event.blockchain_hash)
        @errors << "Invalid event hash format for event #{event.id}"
        return false
      end
    end

    true
  rescue StandardError => e
    @errors << "Hash verification failed: #{e.message}"
    false
  end

  # Calculate local hash for data integrity verification
  # @return [String] calculated hash
  def calculate_local_hash
    data = {
      blockchain_id: @provenance.blockchain_id,
      product_id: @provenance.product_id,
      blockchain: @provenance.blockchain,
      created_at: @provenance.created_at,
      origin_data: @provenance.origin_data
    }

    EventHash.from_data(data).to_s
  end

  # Calculate expected hash for event
  # @param event [ProvenanceEvent] event to hash
  # @param index [Integer] event index in chain
  # @return [String] expected hash
  def calculate_event_hash(event, index)
    data = {
      provenance_id: event.blockchain_provenance_id,
      event_type: event.event_type,
      description: event.description,
      event_data: event.event_data.to_hash,
      occurred_at: event.occurred_at,
      index: index
    }

    EventHash.from_data(data).to_s
  end

  # Normalize hash for comparison
  # @param hash [String] hash to normalize
  # @return [String] normalized hash
  def normalize_hash(hash)
    return '' if hash.nil?

    hash.to_s.downcase.gsub(/^0x/, '')
  end

  # Validate hash format
  # @param hash [String] hash to validate
  # @return [Boolean] true if valid format
  def valid_hash_format?(hash)
    return false if hash.nil?

    hash.match?(/^0x[a-fA-F0-9]{64}$/)
  end

  # Add non-critical warnings to verification result
  def add_verification_warnings
    warnings = []

    # Warning for old provenance records
    if @provenance.created_at < 30.days.ago
      warnings << 'Provenance record is older than 30 days'
    end

    # Warning for high event volume
    if @provenance.provenance_events.count > 100
      warnings << 'High number of events may indicate complex provenance chain'
    end

    # Warning for blockchain network issues
    if @blockchain_data[:gas_used].to_i > 500000
      warnings << 'High gas usage detected in blockchain transaction'
    end

    @verification_result[:warnings] = warnings
  end

  # Update provenance verification status
  def update_verification_status
    if @verification_result[:verified]
      @provenance.update!(
        verified: true,
        verified_at: Time.current,
        verification_hash: @blockchain_data[:hash]
      )
    end
  rescue ActiveRecord::RecordInvalid => e
    @errors << "Failed to update verification status: #{e.message}"
    raise VerificationError, "Status update failed: #{@errors.join(', ')}"
  end

  # Get final verification result
  # @return [Hash] verification result
  def verification_result
    @verification_result.merge(
      provenance_id: @provenance.id,
      blockchain_id: @provenance.blockchain_id,
      verified_at: @provenance.verified_at,
      next_verification_due: calculate_next_verification_due
    )
  end

  # Calculate when next verification should occur
  # @return [Time] next verification time
  def calculate_next_verification_due
    # Verify daily for first week, then weekly
    if @provenance.created_at > 7.days.ago
      1.day.from_now
    else
      7.days.from_now
    end
  end
end