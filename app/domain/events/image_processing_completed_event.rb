# frozen_string_literal: true

# Domain event representing the completion of image processing
# Indicates that image analysis, validation, and optimization is finished
class ImageProcessingCompletedEvent < CameraCaptureEvent
  attr_reader :processing_results, :validation_status, :optimization_data, :analysis_metadata

  # Processing status values
  PROCESSING_STATUS = {
    success: 'success',
    partial_success: 'partial_success',
    failed: 'failed',
    rejected: 'rejected'
  }.freeze

  # Create new image processing completed event
  # @param aggregate_id [String] camera capture aggregate ID
  # @param processing_results [Hash] results of processing operations
  # @param validation_status [Symbol] validation outcome
  # @param optimization_data [Hash] optimization results
  # @param analysis_metadata [Hash] analysis findings
  # @param metadata [Hash] additional event metadata
  def initialize(
    aggregate_id,
    processing_results:,
    validation_status:,
    optimization_data: {},
    analysis_metadata: {},
    **metadata
  )
    super(aggregate_id, metadata: metadata)

    @processing_results = processing_results.freeze
    @validation_status = validation_status.to_sym
    @optimization_data = optimization_data.freeze
    @analysis_metadata = analysis_metadata.freeze

    validate_event_data!
  end

  # Get event data for serialization
  # @return [Hash] serializable event data
  def event_data
    super.merge(
      processing_results: @processing_results,
      validation_status: @validation_status,
      optimization_data: @optimization_data,
      analysis_metadata: @analysis_metadata
    )
  end

  # Check if processing was successful
  # @return [Boolean] true if successful
  def success?
    @validation_status == :success
  end

  # Check if processing had partial success
  # @return [Boolean] true if partial success
  def partial_success?
    @validation_status == :partial_success
  end

  # Check if processing failed
  # @return [Boolean] true if failed
  def failed?
    @validation_status == :failed || @validation_status == :rejected
  end

  # Get quality score after processing
  # @return [Float] quality score 0.0-1.0
  def final_quality_score
    @processing_results[:quality_score] || @analysis_metadata[:quality_score] || 0.0
  end

  # Get processing performance metrics
  # @return [Hash] performance metrics
  def performance_metrics
    {
      processing_time: @processing_results[:processing_time],
      memory_used: @processing_results[:memory_used],
      cpu_usage: @processing_results[:cpu_usage],
      optimization_ratio: calculate_optimization_ratio,
      quality_improvement: calculate_quality_improvement
    }
  end

  # Get validation findings
  # @return [Array<String>] validation issues or findings
  def validation_findings
    @processing_results[:validation_findings] || []
  end

  # Get security scan results
  # @return [Hash] security analysis results
  def security_scan_results
    @analysis_metadata[:security_scan] || {}
  end

  # Check if image contains potential security threats
  # @return [Boolean] true if threats detected
  def security_threats_detected?
    security_scan_results[:threats_detected] || false
  end

  # Get content analysis results
  # @return [Hash] content analysis findings
  def content_analysis
    @analysis_metadata[:content_analysis] || {}
  end

  # Get extracted features for machine learning
  # @return [Hash] extracted image features
  def extracted_features
    @analysis_metadata[:extracted_features] || {}
  end

  # Get optimization recommendations
  # @return [Array<String>] optimization suggestions
  def optimization_recommendations
    recommendations = []

    if final_quality_score < 0.7
      recommendations << 'Consider recapture with better lighting'
    end

    if performance_metrics[:optimization_ratio] < 0.5
      recommendations << 'Image can be further optimized for size'
    end

    if security_threats_detected?
      recommendations << 'Security threats detected - manual review required'
    end

    recommendations
  end

  # Get storage optimization suggestions
  # @return [Hash] storage optimization recommendations
  def storage_optimization
    {
      suggested_format: @optimization_data[:suggested_format],
      compression_level: @optimization_data[:compression_level],
      expected_size_reduction: @optimization_data[:size_reduction_percent],
      cdn_ready: @optimization_data[:cdn_ready] || false
    }
  end

  private

  # Validate event-specific data
  def validate_event_data!
    valid_statuses = PROCESSING_STATUS.values.map(&:to_sym)
    raise ArgumentError, 'Invalid validation status' unless valid_statuses.include?(@validation_status)
    raise ArgumentError, 'Processing results are required' unless @processing_results
  end

  # Calculate optimization ratio
  # @return [Float] optimization ratio
  def calculate_optimization_ratio
    return 0.0 unless @optimization_data[:original_size] && @optimization_data[:optimized_size]

    original_size = @optimization_data[:original_size]
    optimized_size = @optimization_data[:optimized_size]

    return 0.0 if original_size.zero?

    1.0 - (optimized_size.to_f / original_size)
  end

  # Calculate quality improvement
  # @return [Float] quality improvement delta
  def calculate_quality_improvement
    return 0.0 unless @processing_results[:quality_improvement]

    @processing_results[:quality_improvement]
  end
end