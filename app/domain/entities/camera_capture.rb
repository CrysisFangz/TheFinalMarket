# frozen_string_literal: true

# Domain Entity representing a camera capture operation
# Implements event sourcing with immutable state and rich domain behavior
class CameraCapture
  attr_reader :id, :user_id, :capture_type, :image_metadata, :device_info,
              :processing_status, :created_at, :updated_at, :version, :uncommitted_events

  # Processing status values
  PROCESSING_STATUS = {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed',
    rejected: 'rejected'
  }.freeze

  # Create new camera capture entity
  # @param id [String] unique identifier
  # @param user_id [Integer] user who captured the image
  # @param capture_type [CaptureType] type of capture
  # @param image_metadata [ImageMetadata] image properties
  # @param device_info [DeviceInfo] device information
  # @param created_at [Time] creation timestamp
  def initialize(id, user_id, capture_type, image_metadata, device_info, created_at: nil)
    @id = id
    @user_id = user_id
    @capture_type = capture_type
    @image_metadata = image_metadata
    @device_info = device_info
    @created_at = created_at || Time.current
    @updated_at = @created_at
    @version = 1
    @uncommitted_events = []
    @processing_status = :pending

    validate!
    apply_image_captured_event
  end

  # Load entity from event stream
  # @param id [String] entity identifier
  # @param events [Array<CameraCaptureEvent>] historical events
  # @return [CameraCapture] reconstructed entity
  def self.from_events(id, events)
    return nil if events.empty?

    # Sort events by timestamp to ensure proper order
    sorted_events = events.sort_by(&:timestamp)

    # Create entity from first event
    first_event = sorted_events.first
    entity_data = first_event.is_a?(ImageCapturedEvent) ? first_event : nil

    unless entity_data
      raise ArgumentError, 'First event must be ImageCapturedEvent'
    end

    entity = allocate
    entity.instance_variable_set(:@id, id)
    entity.instance_variable_set(:@user_id, entity_data.user_id)
    entity.instance_variable_set(:@capture_type, entity_data.capture_type)
    entity.instance_variable_set(:@image_metadata, entity_data.image_metadata)
    entity.instance_variable_set(:@device_info, entity_data.device_info)
    entity.instance_variable_set(:@created_at, first_event.timestamp)
    entity.instance_variable_set(:@updated_at, first_event.timestamp)
    entity.instance_variable_set(:@version, 0)
    entity.instance_variable_set(:@uncommitted_events, [])
    entity.instance_variable_set(:@processing_status, :pending)

    # Apply all events to reconstruct current state
    sorted_events.each do |event|
      entity.apply_event(event)
    end

    entity
  end

  # Start image processing
  # @return [ImageProcessingStartedEvent] generated event
  def start_processing
    return nil if @processing_status != :pending

    event = ImageProcessingStartedEvent.new(
      @id,
      processing_started_at: Time.current,
      priority: calculate_processing_priority,
      estimated_completion: calculate_estimated_completion
    )

    apply_event(event)
    event
  end

  # Complete image processing
  # @param processing_results [Hash] processing results
  # @param validation_status [Symbol] validation status
  # @return [ImageProcessingCompletedEvent] generated event
  def complete_processing(processing_results, validation_status)
    return nil if @processing_status != :processing

    event = ImageProcessingCompletedEvent.new(
      @id,
      processing_results: processing_results,
      validation_status: validation_status,
      optimization_data: processing_results[:optimization_data] || {},
      analysis_metadata: processing_results[:analysis_metadata] || {}
    )

    apply_event(event)
    event
  end

  # Mark processing as failed
  # @param error_message [String] failure reason
  # @param error_code [String] error code
  # @return [ImageProcessingFailedEvent] generated event
  def fail_processing(error_message, error_code = 'PROCESSING_ERROR')
    return nil if @processing_status == :completed

    event = ImageProcessingFailedEvent.new(
      @id,
      error_message: error_message,
      error_code: error_code,
      failure_timestamp: Time.current,
      retry_recommended: should_retry?(error_code)
    )

    apply_event(event)
    event
  end

  # Archive the capture
  # @param reason [String] reason for archiving
  # @return [CameraCaptureArchivedEvent] generated event
  def archive(reason = 'manual_archive')
    return nil if @processing_status == :archived

    event = CameraCaptureArchivedEvent.new(
      @id,
      archived_at: Time.current,
      reason: reason,
      retention_until: calculate_retention_date
    )

    apply_event(event)
    event
  end

  # Check if capture is ready for deletion
  # @return [Boolean] true if can be deleted
  def can_be_deleted?
    return false if @processing_status == :processing
    return true if @processing_status == :failed

    # Check retention policy based on capture type
    Time.current > retention_deadline
  end

  # Get fraud risk assessment
  # @return [Hash] fraud risk analysis
  def fraud_risk_assessment
    risk_factors = []

    # Device-based risks
    risk_factors << { factor: 'suspicious_location', weight: 0.3 } if @device_info.suspicious_location?
    risk_factors << { factor: 'untrusted_device', weight: 0.2 } unless @device_info.trusted_device?

    # Capture type risks
    case @capture_type.fraud_risk
    when :critical
      risk_factors << { factor: 'critical_capture_type', weight: 0.9 }
    when :high
      risk_factors << { factor: 'high_risk_capture_type', weight: 0.7 }
    when :medium
      risk_factors << { factor: 'medium_risk_capture_type', weight: 0.4 }
    end

    # Image quality risks
    unless @image_metadata.meets_quality_requirements?(@capture_type)
      risk_factors << { factor: 'poor_image_quality', weight: 0.3 }
    end

    total_risk = risk_factors.sum { |r| r[:weight] }
    risk_level = case total_risk
                 when 0.0..0.3 then :low
                 when 0.3..0.6 then :medium
                 when 0.6..0.8 then :high
                 else :critical
                 end

    {
      total_risk: total_risk,
      risk_level: risk_level,
      risk_factors: risk_factors,
      requires_manual_review: total_risk > 0.7,
      enhanced_monitoring: total_risk > 0.5
    }
  end

  # Get storage cost estimate
  # @return [Hash] storage cost information
  def storage_cost_estimate
    base_cost_per_gb = 0.10 # USD per GB per month
    tier_multipliers = { hot: 3.0, warm: 2.0, cold: 1.0 }

    monthly_cost = (@image_metadata.file_size.to_f / (1024**3)) * base_cost_per_gb * tier_multipliers[@capture_type.storage_tier]

    {
      monthly_cost: monthly_cost,
      annual_cost: monthly_cost * 12,
      storage_tier: @capture_type.storage_tier,
      file_size: @image_metadata.file_size,
      retention_days: @capture_type.retention_days,
      total_estimated_cost: monthly_cost * (@capture_type.retention_days / 30.0)
    }
  end

  # Check if capture meets business requirements
  # @return [Hash] compliance check results
  def compliance_check
    issues = []

    # Check image quality
    unless @image_metadata.meets_quality_requirements?(@capture_type)
      issues << 'Image quality below minimum requirements'
    end

    # Check file size limits
    unless @image_metadata.within_file_size_limit?(@capture_type)
      issues << 'File size exceeds maximum allowed for capture type'
    end

    # Check processing status
    if @processing_status == :failed
      issues << 'Processing failed - manual intervention required'
    end

    # Check retention compliance
    if @capture_type.fraud_risk == :critical && @processing_status != :completed
      issues << 'Critical capture type must complete processing'
    end

    {
      compliant: issues.empty?,
      issues: issues,
      severity: issues.empty? ? :none : (issues.length > 2 ? :high : :medium)
    }
  end

  # Apply domain event to change entity state
  # @param event [CameraCaptureEvent] event to apply
  def apply_event(event)
    case event
    when ImageCapturedEvent
      apply_image_captured_event
    when ImageProcessingStartedEvent
      apply_processing_started_event(event)
    when ImageProcessingCompletedEvent
      apply_processing_completed_event(event)
    when ImageProcessingFailedEvent
      apply_processing_failed_event(event)
    when CameraCaptureArchivedEvent
      apply_archived_event(event)
    end

    @version += 1
    @updated_at = event.timestamp
  end

  # Add event to uncommitted events list
  # @param event [CameraCaptureEvent] event to add
  def add_uncommitted_event(event)
    @uncommitted_events << event
  end

  # Mark all events as committed
  def mark_events_committed
    @uncommitted_events.clear
  end

  private

  # Validate entity integrity
  def validate!
    raise ArgumentError, 'ID is required' if @id.blank?
    raise ArgumentError, 'User ID is required' unless @user_id
    raise ArgumentError, 'Capture type is required' unless @capture_type
    raise ArgumentError, 'Image metadata is required' unless @image_metadata
    raise ArgumentError, 'Device info is required' unless @device_info
  end

  # Apply image captured event (initial state)
  def apply_image_captured_event
    # Initial state is already set in constructor
  end

  # Apply processing started event
  # @param event [ImageProcessingStartedEvent] event data
  def apply_processing_started_event(event)
    @processing_status = :processing
  end

  # Apply processing completed event
  # @param event [ImageProcessingCompletedEvent] event data
  def apply_processing_completed_event(event)
    @processing_status = event.success? ? :completed : :failed
  end

  # Apply processing failed event
  # @param event [ImageProcessingFailedEvent] event data
  def apply_processing_failed_event(event)
    @processing_status = :failed
  end

  # Apply archived event
  # @param event [CameraCaptureArchivedEvent] event data
  def apply_archived_event(event)
    @processing_status = :archived
  end

  # Calculate processing priority
  # @return [Integer] priority level
  def calculate_processing_priority
    priority = @capture_type.processing_priority

    # Adjust based on fraud risk
    if fraud_risk_assessment[:total_risk] > 0.7
      priority -= 2
    elsif fraud_risk_assessment[:total_risk] > 0.4
      priority -= 1
    end

    # Adjust based on device trust
    priority -= 1 if @device_info.trusted_device?

    priority
  end

  # Calculate estimated completion time
  # @return [Time] estimated completion timestamp
  def calculate_estimated_completion
    base_time = case @capture_type.type
                when :product_photo then 45
                when :barcode_scan then 10
                when :ar_preview then 60
                when :visual_search then 30
                when :review_photo then 40
                when :profile_photo then 25
                when :document_scan then 75
                else 45
                end

    Time.current + base_time.seconds
  end

  # Check if error should trigger retry
  # @param error_code [String] error code
  # @return [Boolean] true if should retry
  def should_retry?(error_code)
    retryable_codes = ['TEMPORARY_FAILURE', 'NETWORK_ERROR', 'RESOURCE_EXHAUSTED']
    retryable_codes.include?(error_code)
  end

  # Calculate retention deadline
  # @return [Time] when capture can be deleted
  def retention_deadline
    @created_at + @capture_type.retention_days.days
  end

  # Calculate archive retention date
  # @return [Time] when archived capture can be deleted
  def calculate_retention_date
    Time.current + @capture_type.retention_days.days
  end
end