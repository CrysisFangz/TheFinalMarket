# frozen_string_literal: true

# Domain event representing the start of image processing
# Indicates that processing has been initiated for a camera capture
class ImageProcessingStartedEvent < CameraCaptureEvent
  attr_reader :processing_started_at, :priority, :estimated_completion, :processing_node

  # Create new image processing started event
  # @param aggregate_id [String] camera capture aggregate ID
  # @param processing_started_at [Time] when processing started
  # @param priority [Integer] processing priority
  # @param estimated_completion [Time] estimated completion time
  # @param processing_node [String] node/server handling processing
  # @param metadata [Hash] additional event metadata
  def initialize(
    aggregate_id,
    processing_started_at:,
    priority:,
    estimated_completion:,
    processing_node: nil,
    **metadata
  )
    super(aggregate_id, metadata: metadata)

    @processing_started_at = processing_started_at
    @priority = priority
    @estimated_completion = estimated_completion
    @processing_node = processing_node || 'auto-assigned'

    validate_event_data!
  end

  # Get event data for serialization
  # @return [Hash] serializable event data
  def event_data
    super.merge(
      processing_started_at: @processing_started_at,
      priority: @priority,
      estimated_completion: @estimated_completion,
      processing_node: @processing_node
    )
  end

  # Get processing duration estimate
  # @return [Integer] estimated duration in seconds
  def estimated_duration_seconds
    return 0 unless @estimated_completion && @processing_started_at

    @estimated_completion - @processing_started_at
  end

  # Check if processing is high priority
  # @return [Boolean] true if high priority
  def high_priority?
    @priority <= 2
  end

  # Check if processing is expected to be quick
  # @return [Boolean] true if quick processing
  def quick_processing?
    estimated_duration_seconds < 60
  end

  # Get processing queue assignment
  # @return [Symbol] queue name
  def queue_assignment
    if high_priority?
      :high_priority_processing
    elsif quick_processing?
      :fast_processing
    else
      :standard_processing
    end
  end

  # Get resource allocation requirements
  # @return [Hash] resource requirements
  def resource_requirements
    case @priority
    when 1
      { cpu_cores: 4, memory_gb: 8, timeout_minutes: 10 }
    when 2
      { cpu_cores: 2, memory_gb: 4, timeout_minutes: 5 }
    else
      { cpu_cores: 1, memory_gb: 2, timeout_minutes: 3 }
    end
  end

  private

  # Validate event-specific data
  def validate_event_data!
    raise ArgumentError, 'Processing started timestamp is required' unless @processing_started_at
    raise ArgumentError, 'Priority must be positive' if @priority <= 0
    raise ArgumentError, 'Estimated completion is required' unless @estimated_completion

    if @estimated_completion <= @processing_started_at
      raise ArgumentError, 'Estimated completion must be after start time'
    end
  end
end