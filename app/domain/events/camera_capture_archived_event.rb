# frozen_string_literal: true

# Domain event representing the archiving of a camera capture
# Indicates that the capture has been moved to archival storage
class CameraCaptureArchivedEvent < CameraCaptureEvent
  attr_reader :archived_at, :reason, :retention_until, :archive_location, :access_tier

  # Archive reasons
  ARCHIVE_REASONS = {
    manual_archive: 'manual_archive',
    retention_expired: 'retention_expired',
    storage_optimization: 'storage_optimization',
    legal_hold: 'legal_hold',
    compliance_requirement: 'compliance_requirement'
  }.freeze

  # Access tiers for archived data
  ACCESS_TIERS = {
    hot: 'hot',      # Frequent access, low latency
    cool: 'cool',    # Infrequent access, lower cost
    cold: 'cold',    # Rare access, lowest cost
    archive: 'archive' # Rarely accessed, highest compression
  }.freeze

  # Create new camera capture archived event
  # @param aggregate_id [String] camera capture aggregate ID
  # @param archived_at [Time] when archiving occurred
  # @param reason [String] reason for archiving
  # @param retention_until [Time] when data can be deleted
  # @param archive_location [String] storage location identifier
  # @param access_tier [Symbol] access tier for archived data
  # @param metadata [Hash] additional event metadata
  def initialize(
    aggregate_id,
    archived_at:,
    reason:,
    retention_until:,
    archive_location: nil,
    access_tier: :cold,
    **metadata
  )
    super(aggregate_id, metadata: metadata)

    @archived_at = archived_at
    @reason = reason.to_s
    @retention_until = retention_until
    @archive_location = archive_location || generate_archive_location
    @access_tier = access_tier.to_sym

    validate_event_data!
  end

  # Get event data for serialization
  # @return [Hash] serializable event data
  def event_data
    super.merge(
      archived_at: @archived_at,
      reason: @reason,
      retention_until: @retention_until,
      archive_location: @archive_location,
      access_tier: @access_tier
    )
  end

  # Get archive reason category
  # @return [Symbol] reason category
  def reason_category
    ARCHIVE_REASONS[@reason.to_sym] || :unknown
  end

  # Check if archiving was due to retention policy
  # @return [Boolean] true if retention-based
  def retention_based?
    @reason == 'retention_expired'
  end

  # Check if archiving was for storage optimization
  # @return [Boolean] true if optimization-based
  def storage_optimization?
    @reason == 'storage_optimization'
  end

  # Check if archiving was due to legal requirements
  # @return [Boolean] true if legal hold
  def legal_hold?
    @reason == 'legal_hold'
  end

  # Get time until data can be deleted
  # @return [Integer] days until deletion
  def days_until_deletion
    return 0 if @retention_until <= Time.current

    ((@retention_until - Time.current) / 86400).to_i
  end

  # Check if data can be deleted now
  # @return [Boolean] true if can be deleted
  def can_be_deleted?
    @retention_until <= Time.current
  end

  # Get archive cost savings estimate
  # @return [Hash] cost savings information
  def cost_savings_estimate
    # Estimated monthly cost reduction when moving to cold storage
    monthly_savings_per_gb = 0.05 # USD per GB per month

    {
      monthly_savings_usd: monthly_savings_per_gb,
      annual_savings_usd: monthly_savings_per_gb * 12,
      access_tier: @access_tier,
      retrieval_cost: retrieval_cost_estimate,
      retrieval_time: retrieval_time_estimate
    }
  end

  # Get data access requirements for archived data
  # @return [Hash] access requirements
  def access_requirements
    case @access_tier
    when :hot
      { retrieval_time: '< 1 hour', cost_multiplier: 3.0 }
    when :cool
      { retrieval_time: '< 4 hours', cost_multiplier: 2.0 }
    when :cold
      { retrieval_time: '< 12 hours', cost_multiplier: 1.0 }
    when :archive
      { retrieval_time: '< 24 hours', cost_multiplier: 0.5 }
    else
      { retrieval_time: 'unknown', cost_multiplier: 1.0 }
    end
  end

  # Check if archived data requires special handling
  # @return [Boolean] true if special handling required
  def requires_special_handling?
    legal_hold? || reason_category == :compliance_requirement
  end

  # Get audit trail requirements for this archive operation
  # @return [Hash] audit requirements
  def audit_requirements
    {
      requires_detailed_logging: requires_special_handling?,
      requires_approval: legal_hold?,
      requires_notification: true,
      retention_years: calculate_audit_retention,
      compliance_frameworks: determine_compliance_frameworks
    }
  end

  private

  # Validate event-specific data
  def validate_event_data!
    raise ArgumentError, 'Archive timestamp is required' unless @archived_at
    raise ArgumentError, 'Archive reason is required' if @reason.blank?
    raise ArgumentError, 'Retention until date is required' unless @retention_until
    raise ArgumentError, 'Invalid access tier' unless valid_access_tier?

    if @retention_until <= @archived_at
      raise ArgumentError, 'Retention until must be after archive date'
    end
  end

  # Check if access tier is valid
  # @return [Boolean] true if valid
  def valid_access_tier?
    ACCESS_TIERS.key?(@access_tier)
  end

  # Generate archive location identifier
  # @return [String] archive location
  def generate_archive_location
    "archive/#{Time.current.strftime('%Y/%m/%d')}/#{@aggregate_id}"
  end

  # Get estimated retrieval cost
  # @return [Float] cost in USD
  def retrieval_cost_estimate
    case @access_tier
    when :hot then 0.01
    when :cool then 0.05
    when :cold then 0.10
    when :archive then 0.20
    else 0.10
    end
  end

  # Get estimated retrieval time
  # @return [String] time estimate
  def retrieval_time_estimate
    case @access_tier
    when :hot then 'seconds'
    when :cool then 'minutes'
    when :cold then 'hours'
    when :archive then 'hours'
    else 'unknown'
    end
  end

  # Calculate audit retention period
  # @return [Integer] years to retain audit logs
  def calculate_audit_retention
    case @reason
    when 'legal_hold', 'compliance_requirement'
      7 # 7 years for legal compliance
    when 'retention_expired'
      3 # 3 years for retention archives
    else
      2 # 2 years for regular archives
    end
  end

  # Determine applicable compliance frameworks
  # @return [Array<String>] compliance frameworks
  def determine_compliance_frameworks
    frameworks = []

    if legal_hold? || @reason == 'compliance_requirement'
      frameworks << 'GDPR' if @metadata[:gdpr_applicable]
      frameworks << 'CCPA' if @metadata[:ccpa_applicable]
      frameworks << 'SOX' if @metadata[:financial_data]
      frameworks << 'HIPAA' if @metadata[:healthcare_data]
    end

    frameworks.empty? ? ['STANDARD'] : frameworks
  end
end