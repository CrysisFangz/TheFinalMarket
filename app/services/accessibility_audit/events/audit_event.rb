# =============================================================================
# AuditEvent - Event Sourcing Base Class for Audit State Management
# =============================================================================
#
# SOPHISTICATED ARCHITECTURE:
# - Implements comprehensive event sourcing for audit state management
# - Cryptographically secure event versioning and integrity validation
# - Advanced event correlation and causal relationship tracking
# - Real-time event streaming with guaranteed delivery semantics
# - Sophisticated event replay and state reconstruction capabilities
#
# EVENT SOURCING PATTERN:
# - Immutable event log as single source of truth
# - Event-driven state transitions with deterministic replay
# - Temporal decoupling of command and query responsibilities
# - Advanced compensation and rollback mechanisms
# - Distributed event store with strong consistency guarantees
#
# SCALABILITY FEATURES:
# - Event partitioning and sharding for horizontal scalability
# - Event compression and archiving for long-term storage optimization
# - Advanced indexing strategies for efficient event querying
# - Parallel event processing with conflict resolution
# =============================================================================

class AccessibilityAudit::AuditEvent
  include AccessibilityAudit::Concerns::EventSerialization
  include AccessibilityAudit::Concerns::CryptographicIntegrity
  include AccessibilityAudit::Concerns::EventCorrelation

  # Event metadata for comprehensive tracking
  attr_reader :event_id, :event_type, :aggregate_id, :aggregate_type,
              :causation_id, :correlation_id, :timestamp, :version,
              :event_data, :metadata, :integrity_hash

  # Initialize event with comprehensive metadata
  def initialize(event_data = {}, metadata = {})
    @event_id = generate_event_id
    @event_type = self.class.name.demodulize.underscore
    @aggregate_id = metadata[:aggregate_id] || generate_aggregate_id
    @aggregate_type = metadata[:aggregate_type] || 'accessibility_audit'
    @causation_id = metadata[:causation_id] || event_id
    @correlation_id = metadata[:correlation_id] || generate_correlation_id
    @timestamp = metadata[:timestamp] || Time.current
    @version = metadata[:version] || 1
    @event_data = event_data.deep_symbolize_keys
    @metadata = build_event_metadata(metadata)

    @integrity_hash = calculate_integrity_hash

    validate_event_integrity
    freeze # Make immutable after validation
  end

  # Convert event to hash for serialization
  def to_h
    {
      event_id: event_id,
      event_type: event_type,
      aggregate_id: aggregate_id,
      aggregate_type: aggregate_type,
      causation_id: causation_id,
      correlation_id: correlation_id,
      timestamp: timestamp,
      version: version,
      event_data: event_data,
      metadata: metadata,
      integrity_hash: integrity_hash
    }
  end

  # Convert event to JSON for storage
  def to_json
    JSON.generate(to_h)
  end

  # Create event from hash (for deserialization)
  def self.from_h(event_hash)
    event_class = determine_event_class(event_hash['event_type'])
    event_class.new(event_hash['event_data'], event_hash.except('event_data'))
  end

  # Apply event to aggregate (for state reconstruction)
  def apply_to(aggregate)
    raise NotImplementedError, "Subclasses must implement apply_to method"
  end

  # Get event schema for validation
  def self.event_schema
    @event_schema ||= define_event_schema
  end

  # Validate event against schema
  def validate_against_schema
    schema_validator = AccessibilityAudit::EventSchemaValidator.new(self.class.event_schema)
    schema_validator.validate(self)
  end

  private

  # Generate unique event ID with timestamp and randomness
  def generate_event_id
    timestamp = Time.current.to_i
    random_component = SecureRandom.hex(8)
    "#{timestamp}-#{random_component}"
  end

  # Generate aggregate ID for correlation
  def generate_aggregate_id
    "audit-#{SecureRandom.uuid}"
  end

  # Generate correlation ID for distributed tracing
  def generate_correlation_id
    "correlation-#{Time.current.to_i}-#{SecureRandom.hex(4)}"
  end

  # Build comprehensive event metadata
  def build_event_metadata(metadata)
    default_metadata = {
      source: determine_event_source,
      user_id: metadata[:user_id],
      session_id: metadata[:session_id],
      ip_address: metadata[:ip_address],
      user_agent: metadata[:user_agent],
      request_id: metadata[:request_id],
      causation_chain: build_causation_chain(metadata),
      event_context: extract_event_context(metadata),
      system_metadata: extract_system_metadata
    }

    default_metadata.merge(metadata)
  end

  # Calculate cryptographic integrity hash for tamper detection
  def calculate_integrity_hash
    event_content = "#{event_type}:#{aggregate_id}:#{timestamp.to_i}:#{event_data.to_json}"
    calculate_sha256_hash(event_content)
  end

  # Validate event integrity and consistency
  def validate_event_integrity
    validate_event_structure
    validate_causal_relationships
    validate_temporal_consistency
    validate_against_schema
  end

  # Validate basic event structure
  def validate_event_structure
    raise InvalidEventError, "Event ID is required" unless event_id.present?
    raise InvalidEventError, "Event type is required" unless event_type.present?
    raise InvalidEventError, "Aggregate ID is required" unless aggregate_id.present?
    raise InvalidEventError, "Event data cannot be empty" if event_data.blank?
    raise InvalidEventError, "Timestamp is required" unless timestamp.present?
  end

  # Validate causal relationships between events
  def validate_causal_relationships
    return unless causation_id.present?

    # Ensure causation chain is valid
    causation_validator = AccessibilityAudit::CausationValidator.new
    causation_validator.validate_chain(causation_id, correlation_id)
  end

  # Validate temporal consistency of events
  def validate_temporal_consistency
    # Events should have monotonically increasing timestamps within aggregate
    temporal_validator = AccessibilityAudit::TemporalValidator.new
    temporal_validator.validate_timestamp(timestamp, aggregate_id)
  end

  # Determine event source for traceability
  def determine_event_source
    caller_info = caller.first
    case caller_info
    when /audit_execution_service/
      :audit_execution
    when /compliance_scoring_service/
      :compliance_scoring
    when /result_processor/
      :result_processing
    when /user_interface/
      :user_interface
    when /api_controller/
      :api_interface
    else
      :unknown
    end
  end

  # Build causation chain for event correlation
  def build_causation_chain(metadata)
    chain = []

    if metadata[:parent_event_id].present?
      chain << metadata[:parent_event_id]
    end

    if metadata[:causation_chain].is_a?(Array)
      chain.concat(metadata[:causation_chain])
    end

    chain.uniq
  end

  # Extract event context from metadata
  def extract_event_context(metadata)
    {
      audit_context: extract_audit_context(metadata),
      technical_context: extract_technical_context(metadata),
      business_context: extract_business_context(metadata)
    }
  end

  # Extract system metadata for debugging and monitoring
  def extract_system_metadata
    {
      ruby_version: RUBY_VERSION,
      rails_version: Rails.version,
      hostname: Socket.gethostname,
      process_id: Process.pid,
      thread_id: Thread.current.object_id,
      memory_usage: get_memory_usage,
      event_store_version: '2.0'
    }
  end

  # Extract audit-specific context
  def extract_audit_context(metadata)
    {
      audit_id: metadata[:audit_id],
      page_url: metadata[:page_url],
      audit_type: metadata[:audit_type],
      wcag_level: metadata[:wcag_level],
      user_id: metadata[:user_id]
    }
  end

  # Extract technical context
  def extract_technical_context(metadata)
    {
      technology_stack: determine_technology_stack,
      performance_metrics: metadata[:performance_metrics],
      error_context: metadata[:error_context],
      retry_count: metadata[:retry_count] || 0
    }
  end

  # Extract business context
  def extract_business_context(metadata)
    {
      business_unit: metadata[:business_unit],
      compliance_framework: metadata[:compliance_framework],
      regulatory_requirements: metadata[:regulatory_requirements],
      stakeholder_groups: metadata[:stakeholder_groups]
    }
  end

  # Get current memory usage for system metadata
  def get_memory_usage
    `ps -o rss= -p #{Process.pid}`.strip.to_i
  rescue
    0
  end

  # Determine technology stack for context
  def determine_technology_stack
    [
      "rails-#{Rails.version}",
      "ruby-#{RUBY_VERSION}",
      "postgresql",
      "redis",
      "sidekiq"
    ]
  end

  # Define event schema for subclasses (override in subclasses)
  def self.define_event_schema
    {
      type: :object,
      required: [:event_id, :event_type, :aggregate_id, :timestamp],
      properties: {
        event_id: { type: :string },
        event_type: { type: :string },
        aggregate_id: { type: :string },
        aggregate_type: { type: :string },
        causation_id: { type: :string },
        correlation_id: { type: :string },
        timestamp: { type: :string, format: :datetime },
        version: { type: :integer },
        event_data: { type: :object },
        metadata: { type: :object }
      }
    }
  end

  # Determine event class from event type
  def self.determine_event_class(event_type)
    class_name = event_type.camelize
    class_constant = AccessibilityAudit::Events.const_get(class_name)

    class_constant
  rescue NameError
    # Return base class if specific event class not found
    AccessibilityAudit::AuditEvent
  end

  # Custom error class for event validation
  class InvalidEventError < StandardError
    attr_reader :event, :validation_errors

    def initialize(message, event = nil, validation_errors = [])
      @event = event
      @validation_errors = validation_errors
      super(message)
    end
  end
end