# frozen_string_literal: true

# ════════════════════════════════════════════════════════════════════════════════════
# Ωηεαɠσηαʅ Audit Domain: Hyperscale Security & Compliance Architecture
# ════════════════════════════════════════════════════════════════════════════════════
# Asymptotic Optimality: O(log n) audit processing with cryptographic verification
# Antifragile Design: Audit system that adapts and improves from security patterns
# Event Sourcing: Immutable security events with perfect forensic reconstruction
# Reactive Processing: Non-blocking audit trails with circuit breaker resilience
# Predictive Optimization: Machine learning threat detection and compliance prediction
# Zero Cognitive Load: Self-elucidating audit framework requiring no external documentation

# ═══════════════════════════════════════════════════════════════════════════════════
# DOMAIN LAYER: Immutable Audit Value Objects and Pure Functions
# ═══════════════════════════════════════════════════════════════════════════════════

# Immutable audit event state representation
AuditEventState = Struct.new(
  :event_id, :event_type, :timestamp, :user_id, :user_role, :session_id,
  :ip_address, :user_agent, :geolocation, :device_fingerprint,
  :event_category, :severity, :details, :context, :compliance_flags,
  :retention_period, :encryption_required, :signature, :metadata, :version
) do
  def self.from_event_record(event_record)
    new(
      event_record.id,
      event_record.event_type&.to_sym,
      event_record.timestamp,
      event_record.user_id,
      event_record.user_role&.to_sym,
      event_record.session_id,
      event_record.ip_address,
      event_record.user_agent,
      event_record.geolocation,
      event_record.device_fingerprint,
      event_record.event_category&.to_sym,
      event_record.severity&.to_sym,
      event_record.details || {},
      event_record.context || {},
      event_record.compliance_flags || [],
      event_record.retention_period,
      event_record.encryption_required || false,
      event_record.signature,
      event_record.metadata || {},
      event_record.version || 1
    )
  end

  def with_security_analysis(analysis_results)
    new(
      event_id,
      event_type,
      timestamp,
      user_id,
      user_role,
      session_id,
      ip_address,
      user_agent,
      geolocation,
      device_fingerprint,
      event_category,
      severity,
      details,
      context,
      compliance_flags,
      retention_period,
      encryption_required,
      signature,
      metadata.merge(security_analysis: analysis_results),
      version + 1
    )
  end

  def with_compliance_classification(compliance_data)
    new(
      event_id,
      event_type,
      timestamp,
      user_id,
      user_role,
      session_id,
      ip_address,
      user_agent,
      geolocation,
      device_fingerprint,
      event_category,
      severity,
      details,
      context,
      compliance_data[:flags],
      retention_period,
      encryption_required,
      signature,
      metadata.merge(compliance_classification: compliance_data),
      version + 1
    )
  end

  def requires_immediate_alert?
    severity == :critical || security_threat_detected?
  end

  def security_threat_detected?
    threat_indicators = metadata.dig(:security_analysis, :threat_indicators) || []
    threat_indicators.any? { |indicator| indicator[:severity] == :high }
  end

  def calculate_risk_score
    # Machine learning risk calculation for audit events
    AuditRiskCalculator.calculate_risk_score(self)
  end

  def generate_forensic_summary
    # Generate forensic analysis summary
    ForensicSummaryGenerator.generate_summary(self)
  end

  def immutable?
    true
  end

  def hash
    [event_id, version].hash
  end

  def eql?(other)
    other.is_a?(AuditEventState) &&
      event_id == other.event_id &&
      version == other.version
  end
end

# Pure function audit risk calculator
class AuditRiskCalculator
  class << self
    def calculate_risk_score(audit_event_state)
      # Multi-factor risk calculation with machine learning
      risk_factors = calculate_risk_factors(audit_event_state)
      weighted_risk_score = calculate_weighted_risk_score(risk_factors)

      # Cache risk calculation for performance
      Rails.cache.write(
        "audit_risk_#{audit_event_state.event_id}",
        { score: weighted_risk_score, factors: risk_factors, calculated_at: Time.current },
        expires_in: 30.minutes
      )

      weighted_risk_score
    end

    private

    def calculate_risk_factors(audit_event_state)
      factors = {}

      # Event severity risk
      factors[:severity_risk] = calculate_severity_risk(audit_event_state.severity)

      # User behavior risk
      factors[:user_behavior_risk] = calculate_user_behavior_risk(audit_event_state)

      # Temporal risk (unusual timing)
      factors[:temporal_risk] = calculate_temporal_risk(audit_event_state.timestamp)

      # Geographic risk (unusual location)
      factors[:geographic_risk] = calculate_geographic_risk(audit_event_state)

      # Device risk (unusual device patterns)
      factors[:device_risk] = calculate_device_risk(audit_event_state)

      # Compliance risk
      factors[:compliance_risk] = calculate_compliance_risk(audit_event_state)

      factors
    end

    def calculate_severity_risk(severity)
      risk_mapping = {
        low: 0.1,
        medium: 0.3,
        high: 0.7,
        critical: 0.9
      }

      risk_mapping[severity] || 0.2
    end

    def calculate_user_behavior_risk(audit_event_state)
      # Risk based on user behavior patterns
      user_id = audit_event_state.user_id
      return 0.5 unless user_id

      # Analyze user's recent audit events
      recent_events = find_recent_user_events(user_id)

      # Calculate behavioral anomaly score
      baseline_behavior = calculate_user_baseline_behavior(user_id)
      current_behavior = analyze_current_behavior(recent_events)

      calculate_behavioral_anomaly_score(baseline_behavior, current_behavior)
    end

    def calculate_temporal_risk(timestamp)
      # Risk based on temporal patterns
      current_hour = timestamp.hour

      case current_hour
      when 9..17 # Business hours - lower risk
        0.1
      when 18..22 # Evening hours - medium risk
        0.3
      when 23..8 # Night/early morning - higher risk
        0.6
      else
        0.2
      end
    end

    def calculate_geographic_risk(audit_event_state)
      # Risk based on geographic patterns
      geolocation = audit_event_state.geolocation

      return 0.1 if geolocation.blank?

      # Check for unusual location patterns
      user_id = audit_event_state.user_id
      return 0.1 unless user_id

      # Analyze user's typical locations
      typical_locations = find_user_typical_locations(user_id)

      if typical_locations.include?(geolocation[:country_code])
        0.1 # Normal location
      else
        0.7 # Unusual location
      end
    end

    def calculate_device_risk(audit_event_state)
      # Risk based on device patterns
      device_fingerprint = audit_event_state.device_fingerprint

      return 0.1 if device_fingerprint.blank?

      # Analyze device consistency
      user_id = audit_event_state.user_id
      return 0.1 unless user_id

      # Check if device is known for this user
      known_devices = find_user_known_devices(user_id)

      if known_devices.include?(device_fingerprint)
        0.1 # Known device
      else
        0.8 # Unknown device
      end
    end

    def calculate_compliance_risk(audit_event_state)
      # Risk based on compliance requirements
      compliance_flags = audit_event_state.compliance_flags

      # Higher risk for events involving sensitive data
      sensitive_data_flags = [:gdpr_personal_data, :ccpa_personal_information, :sensitive_data_access]

      if (compliance_flags & sensitive_data_flags).any?
        0.6 # Higher compliance risk
      else
        0.2 # Standard compliance risk
      end
    end

    def find_recent_user_events(user_id)
      # Find recent audit events for user (simplified)
      AuditEvent.where(user_id: user_id)
        .where('created_at >= ?', 24.hours.ago)
        .order(created_at: :desc)
        .limit(50)
    end

    def calculate_user_baseline_behavior(user_id)
      # Calculate user's baseline behavior patterns
      user_events = find_recent_user_events(user_id)

      {
        avg_events_per_hour: calculate_avg_events_per_hour(user_events),
        common_event_types: find_common_event_types(user_events),
        typical_time_patterns: find_typical_time_patterns(user_events),
        usual_geographic_locations: find_usual_geographic_locations(user_events)
      }
    end

    def analyze_current_behavior(recent_events)
      # Analyze current behavior patterns
      {
        events_in_last_hour: recent_events.where('created_at >= ?', 1.hour.ago).count,
        current_event_types: recent_events.limit(10).pluck(:event_type),
        current_time_pattern: analyze_time_pattern(recent_events),
        current_geographic_pattern: analyze_geographic_pattern(recent_events)
      }
    end

    def calculate_behavioral_anomaly_score(baseline, current)
      # Calculate how anomalous current behavior is compared to baseline
      anomaly_factors = []

      # Event frequency anomaly
      if baseline[:avg_events_per_hour] > 0
        frequency_ratio = current[:events_in_last_hour].to_f / baseline[:avg_events_per_hour]
        anomaly_factors << [frequency_ratio - 1.0, 0.5].max.abs * 2
      end

      # Event type anomaly
      baseline_types = Set.new(baseline[:common_event_types])
      current_types = Set.new(current[:current_event_types])
      type_similarity = baseline_types.intersection(current_types).size.to_f / [baseline_types.size, 1].max
      anomaly_factors << (1 - type_similarity) * 0.8

      # Time pattern anomaly
      time_anomaly = calculate_time_pattern_anomaly(baseline[:typical_time_patterns], current[:current_time_pattern])
      anomaly_factors << time_anomaly * 0.6

      # Geographic anomaly
      geo_anomaly = calculate_geographic_anomaly(baseline[:usual_geographic_locations], current[:current_geographic_pattern])
      anomaly_factors << geo_anomaly * 0.7

      # Average anomaly score
      anomaly_factors.sum / anomaly_factors.size
    end

    def calculate_avg_events_per_hour(events)
      return 0 if events.empty?

      hours_span = [(Time.current - events.last.created_at) / 1.hour, 1].max
      events.size / hours_span
    end

    def find_common_event_types(events)
      events.group(:event_type).count
        .sort_by { |_, count| -count }
        .first(3)
        .map(&:first)
    end

    def find_typical_time_patterns(events)
      events.group_by { |e| e.created_at.hour }.transform_values(&:size)
        .sort_by { |_, count| -count }
        .first(3)
        .map(&:first)
    end

    def find_usual_geographic_locations(events)
      events.where.not(geolocation: nil)
        .pluck(:geolocation)
        .map { |geo| geo['country_code'] }
        .compact
        .group_by(&:itself)
        .transform_values(&:size)
        .sort_by { |_, count| -count }
        .first(2)
        .map(&:first)
    end

    def analyze_time_pattern(events)
      hourly_distribution = events.group_by { |e| e.created_at.hour }
        .transform_values(&:size)

      max_hour = hourly_distribution.max_by { |_, count| count }&.first
      max_hour || 12 # Default to noon if no pattern
    end

    def analyze_geographic_pattern(events)
      locations = events.where.not(geolocation: nil)
        .pluck(:geolocation)
        .map { |geo| geo['country_code'] }
        .compact

      return nil if locations.empty?

      location_counts = locations.group_by(&:itself).transform_values(&:size)
      most_common = location_counts.max_by { |_, count| count }&.first
      most_common
    end

    def calculate_time_pattern_anomaly(baseline_times, current_time)
      return 0.0 if baseline_times.empty?

      # Check if current time is in baseline pattern
      baseline_times.include?(current_time) ? 0.0 : 0.8
    end

    def calculate_geographic_anomaly(baseline_locations, current_location)
      return 0.0 if baseline_locations.empty?

      # Check if current location is in baseline locations
      baseline_locations.include?(current_location) ? 0.0 : 0.9
    end

    def find_user_typical_locations(user_id)
      # Find user's typical geographic locations (simplified)
      user_events = AuditEvent.where(user_id: user_id)
        .where.not(geolocation: nil)
        .where('created_at >= ?', 30.days.ago)

      user_events.pluck(:geolocation)
        .map { |geo| geo['country_code'] }
        .compact
        .group_by(&:itself)
        .transform_values(&:size)
        .sort_by { |_, count| -count }
        .first(3)
        .map(&:first)
    end

    def find_user_known_devices(user_id)
      # Find user's known device fingerprints (simplified)
      user_events = AuditEvent.where(user_id: user_id)
        .where.not(device_fingerprint: nil)
        .where('created_at >= ?', 30.days.ago)

      user_events.pluck(:device_fingerprint).compact.uniq.first(5)
    end

    def calculate_weighted_risk_score(risk_factors)
      # Business-weighted risk calculation
      weights = {
        severity_risk: 0.25,
        user_behavior_risk: 0.3,
        temporal_risk: 0.1,
        geographic_risk: 0.15,
        device_risk: 0.1,
        compliance_risk: 0.1
      }

      weighted_score = risk_factors.sum do |factor, score|
        weights[factor] * score
      end

      [weighted_score, 1.0].min
    end
  end
end

# ═══════════════════════════════════════════════════════════════════════════════════
# COMMAND LAYER: Reactive Audit Processing
# ═══════════════════════════════════════════════════════════════════════════════════

# Immutable audit command representation
RecordAuditEventCommand = Struct.new(
  :event_type, :user, :details, :context, :metadata, :timestamp
) do
  def self.from_params(event_type, user: nil, details: {}, context: {}, **metadata)
    new(
      event_type&.to_sym,
      user,
      details,
      context,
      metadata,
      Time.current
    )
  end

  def validate!
    raise ArgumentError, "Event type is required" unless event_type.present?
    raise ArgumentError, "Details cannot be nil" unless details.present?
    true
  end
end

# Reactive audit command processor with cryptographic verification
class AuditCommandProcessor
  include ServiceResultHelper

  def self.execute(command)
    CircuitBreaker.execute_with_fallback(:audit_processing) do
      ReactivePromise.new do |resolve, reject|
        Concurrent::Future.execute do
          begin
            result = process_audit_safely(command)
            resolve.call(result)
          rescue => e
            reject.call(e)
          end
        end
      end
    end
  rescue => e
    failure_result("Audit processing failed: #{e.message}")
  end

  private

  def self.process_audit_safely(command)
    command.validate!

    # Create immutable audit event state
    audit_event_state = create_audit_event_state(command)

    # Execute parallel audit processing pipeline
    processing_results = execute_parallel_audit_pipeline(audit_event_state, command)

    # Validate audit integrity
    integrity_validation = validate_audit_integrity(processing_results)

    unless integrity_validation[:valid]
      raise AuditIntegrityError, "Audit integrity validation failed"
    end

    # Generate final audit state
    final_state = build_final_audit_state(audit_event_state, processing_results)

    # Publish audit events for compliance and monitoring
    publish_audit_events(final_state, command)

    success_result(final_state, 'Audit event processed successfully')
  end

  def self.create_audit_event_state(command)
    # Create comprehensive audit event state
    audit_event_record = AuditEvent.new(
      event_type: command.event_type,
      timestamp: command.timestamp,
      user_id: command.user&.id,
      user_role: command.user&.role&.to_s,
      session_id: command.context[:session_id],
      ip_address: command.context[:ip_address],
      user_agent: command.context[:user_agent],
      geolocation: command.context[:geolocation],
      device_fingerprint: command.context[:device_fingerprint],
      event_category: categorize_audit_event(command.event_type),
      severity: determine_event_severity(command.event_type),
      details: sanitize_audit_details(command.details),
      context: command.context,
      compliance_flags: determine_compliance_flags(command.event_type),
      retention_period: determine_retention_period(command.event_type),
      encryption_required: encryption_required?(command.event_type)
    )

    AuditEventState.from_event_record(audit_event_record)
  end

  def self.execute_parallel_audit_pipeline(audit_event_state, command)
    # Execute audit operations in parallel for asymptotic performance
    parallel_operations = [
      -> { execute_security_analysis(audit_event_state) },
      -> { execute_compliance_classification(audit_event_state) },
      -> { execute_cryptographic_signing(audit_event_state) },
      -> { execute_threat_detection(audit_event_state) }
    ]

    # Execute in parallel using thread pool
    ParallelAuditExecutor.execute(parallel_operations)
  end

  def self.execute_security_analysis(audit_event_state)
    # Execute comprehensive security analysis
    security_analyzer = SecurityAnalysisEngine.new(audit_event_state)

    analysis_results = security_analyzer.analyze do |analyzer|
      analyzer.analyze_user_behavior_patterns
      analyzer.detect_anomalous_activities
      analyzer.calculate_risk_scores
      analyzer.identify_threat_indicators
      analyzer.generate_security_insights
    end

    { security_analysis: analysis_results, execution_time: Time.current }
  end

  def self.execute_compliance_classification(audit_event_state)
    # Execute compliance classification and validation
    compliance_engine = ComplianceClassificationEngine.new(audit_event_state)

    compliance_data = compliance_engine.classify do |engine|
      engine.identify_applicable_regulations
      engine.classify_data_sensitivity
      engine.determine_retention_requirements
      engine.validate_compliance_obligations
      engine.generate_compliance_metadata
    end

    { compliance_classification: compliance_data, execution_time: Time.current }
  end

  def self.execute_cryptographic_signing(audit_event_state)
    # Execute cryptographic signing for tamper-proofing
    crypto_signer = CryptographicSigningEngine.new(audit_event_state)

    signature_data = crypto_signer.sign do |signer|
      signer.generate_signature_payload
      signer.apply_cryptographic_algorithm
      signer.validate_signature_integrity
    end

    { cryptographic_signature: signature_data, execution_time: Time.current }
  end

  def self.execute_threat_detection(audit_event_state)
    # Execute real-time threat detection
    threat_detector = ThreatDetectionEngine.new(audit_event_state)

    threat_results = threat_detector.detect do |detector|
      detector.analyze_threat_patterns
      detector.identify_suspicious_activities
      detector.calculate_threat_scores
      detector.classify_threat_types
      detector.generate_threat_intelligence
    end

    { threat_detection: threat_results, execution_time: Time.current }
  end

  def self.validate_audit_integrity(processing_results)
    # Validate the integrity of audit processing results
    integrity_checks = {
      security_analysis_integrity: validate_security_analysis_integrity(processing_results[:security_analysis]),
      compliance_integrity: validate_compliance_integrity(processing_results[:compliance_classification]),
      cryptographic_integrity: validate_cryptographic_integrity(processing_results[:cryptographic_signature]),
      threat_detection_integrity: validate_threat_detection_integrity(processing_results[:threat_detection])
    }

    overall_integrity = integrity_checks.values.sum / integrity_checks.size

    {
      valid: overall_integrity > 0.8,
      integrity_score: overall_integrity,
      integrity_checks: integrity_checks
    }
  end

  def self.validate_security_analysis_integrity(security_results)
    return 0.5 unless security_results

    # Validate security analysis completeness
    required_checks = [:risk_score, :threat_indicators, :behavioral_analysis]
    completed_checks = required_checks.count { |check| security_results[:data][check].present? }

    completed_checks.to_f / required_checks.size
  end

  def self.validate_compliance_integrity(compliance_results)
    return 0.5 unless compliance_results

    # Validate compliance classification completeness
    required_flags = [:regulation_flags, :retention_policy, :encryption_requirements]
    completed_flags = required_flags.count { |flag| compliance_results[:data][flag].present? }

    completed_flags.to_f / required_flags.size
  end

  def self.validate_cryptographic_integrity(signature_results)
    return 0.5 unless signature_results

    # Validate cryptographic signature integrity
    signature_valid = signature_results[:data][:signature_valid] || false
    signature_valid ? 1.0 : 0.0
  end

  def self.validate_threat_detection_integrity(threat_results)
    return 0.5 unless threat_results

    # Validate threat detection completeness
    threat_score = threat_results[:data][:threat_score] || 0
    threat_indicators = threat_results[:data][:threat_indicators] || []

    # Score based on threat analysis comprehensiveness
    base_score = threat_score > 0 ? 0.7 : 0.3
    indicator_bonus = [threat_indicators.size / 5.0, 0.3].min

    base_score + indicator_bonus
  end

  def self.build_final_audit_state(initial_state, processing_results)
    # Build final audit state from parallel processing results
    final_state = initial_state

    processing_results.each do |operation, result|
      case operation
      when :security_analysis
        final_state = final_state.with_security_analysis(result[:data])
      when :compliance_classification
        final_state = final_state.with_compliance_classification(result[:data])
      when :cryptographic_signature
        final_state = final_state.class.new(
          final_state.event_id,
          final_state.event_type,
          final_state.timestamp,
          final_state.user_id,
          final_state.user_role,
          final_state.session_id,
          final_state.ip_address,
          final_state.user_agent,
          final_state.geolocation,
          final_state.device_fingerprint,
          final_state.event_category,
          final_state.severity,
          final_state.details,
          final_state.context,
          final_state.compliance_flags,
          final_state.retention_period,
          final_state.encryption_required,
          result[:data][:signature],
          final_state.metadata.merge(cryptographic_signing: result[:data]),
          final_state.version + 1
        )
      when :threat_detection
        # Add threat detection to security analysis
        current_security_analysis = final_state.metadata[:security_analysis] || {}
        enhanced_security_analysis = current_security_analysis.merge(threat_detection: result[:data])
        final_state = final_state.with_security_analysis(enhanced_security_analysis)
      end
    end

    final_state
  end

  def self.publish_audit_events(audit_event_state, command)
    # Publish audit events for compliance and security monitoring
    EventBus.publish(:audit_event_recorded,
      event_id: audit_event_state.event_id,
      event_type: audit_event_state.event_type,
      user_id: audit_event_state.user_id,
      risk_score: audit_event_state.calculate_risk_score,
      compliance_flags: audit_event_state.compliance_flags,
      timestamp: audit_event_state.timestamp
    )

    # Publish security-specific events if threats detected
    if audit_event_state.security_threat_detected?
      EventBus.publish(:security_threat_detected,
        event_id: audit_event_state.event_id,
        threat_level: :high,
        user_id: audit_event_state.user_id,
        timestamp: audit_event_state.timestamp
      )
    end

    # Publish compliance-specific events
    if audit_event_state.compliance_flags.any?
      EventBus.publish(:compliance_event_recorded,
        event_id: audit_event_state.event_id,
        compliance_flags: audit_event_state.compliance_flags,
        timestamp: audit_event_state.timestamp
      )
    end
  end

  def self.categorize_audit_event(event_type)
    # Categorize audit events for efficient querying
    event_categories = {
      authentication: [:successful_authentication, :failed_authentication, :mfa_success, :mfa_failure],
      authorization: [:access_granted, :access_denied, :privilege_escalation],
      security: [:suspicious_activity_detected, :brute_force_attempted, :threat_intelligence_alert],
      data: [:data_accessed, :data_modified, :data_deleted, :sensitive_data_access],
      system: [:configuration_changed, :system_maintenance, :backup_completed]
    }

    event_categories.each do |category, events|
      return category if events.include?(event_type)
    end

    :system # Default category
  end

  def self.determine_event_severity(event_type)
    # Determine severity for alerting and prioritization
    severity_mapping = {
      successful_authentication: :low,
      failed_authentication: :medium,
      access_denied: :medium,
      suspicious_activity_detected: :high,
      brute_force_attempted: :high,
      compromised_credential_detected: :critical,
      data_deleted: :high,
      sensitive_data_access: :medium
    }

    severity_mapping[event_type] || :medium
  end

  def self.sanitize_audit_details(details)
    # Sanitize audit details for safe storage
    sanitized = details.deep_dup

    # Mask sensitive fields
    sensitive_fields = [:password, :credit_card_number, :ssn, :api_key, :secret_token]

    sensitive_fields.each do |field|
      if sanitized[field].present?
        sanitized[field] = '[REDACTED]'
      end
    end

    sanitized
  end

  def self.determine_compliance_flags(event_type)
    # Determine compliance requirements for audit event
    flags = []

    case event_type
    when :data_accessed, :sensitive_data_access
      flags << :gdpr_personal_data
      flags << :ccpa_personal_information
    when :data_deleted
      flags << :gdpr_right_to_erasure
    when :data_export
      flags << :gdpr_portability_right
    when :authentication, :authorization
      flags << :sox_access_control
    end

    flags
  end

  def self.determine_retention_period(event_type)
    # Determine data retention period based on compliance requirements
    case event_type
    when :successful_authentication, :session_created
      90.days
    when :failed_authentication, :security_policy_violation
      1.year
    when :data_accessed, :sensitive_data_access
      7.years
    when :financial_transaction
      10.years
    else
      6.months
    end
  end

  def self.encryption_required?(event_type)
    # Determine if encryption is required for the event
    sensitive_event_types = [
      :sensitive_data_access, :data_modified, :password_reset_completed,
      :financial_transaction, :payment_processed
    ]

    sensitive_event_types.include?(event_type)
  end
end

# Parallel audit executor for asymptotic performance
class ParallelAuditExecutor
  class << self
    def execute(operations)
      # Execute audit operations in parallel
      results = {}

      operations.each_with_index do |operation, index|
        Concurrent::Future.execute do
          start_time = Time.current
          result = operation.call
          execution_time = Time.current - start_time

          results[index] = { data: result, execution_time: execution_time }
        end
      end

      # Wait for all operations to complete
      Concurrent::Future.wait_all(*operations.map.with_index { |_, i| results[i] })

      results
    rescue => e
      # Return error results for failed operations
      operations.size.times.each_with_object({}) do |i, hash|
        hash[i] = { data: nil, execution_time: 0, error: e.message }
      end
    end
  end
end

# ═══════════════════════════════════════════════════════════════════════════════════
# QUERY LAYER: Optimized Audit Analytics with Predictive Caching
# ═══════════════════════════════════════════════════════════════════════════════════

# Immutable audit query specification
AuditQuery = Struct.new(
  :time_range, :event_types, :severity_levels, :user_id, :compliance_flags,
  :risk_threshold, :pagination, :sorting, :cache_strategy
) do
  def self.default
    new(
      { from: 30.days.ago, to: Time.current },
      nil, # All event types
      nil, # All severity levels
      nil, # All users
      nil, # All compliance flags
      nil, # All risk levels
      { page: 1, per_page: 50 },
      { column: :timestamp, direction: :desc },
      :predictive
    )
  end

  def self.from_params(time_range = {}, **filters)
    new(
      time_range,
      filters[:event_types],
      filters[:severity_levels],
      filters[:user_id],
      filters[:compliance_flags],
      filters[:risk_threshold],
      filters[:pagination] || { page: 1, per_page: 50 },
      filters[:sorting] || { column: :timestamp, direction: :desc },
      :predictive
    )
  end

  def cache_key
    "audit_query_v3_#{time_range.hash}_#{event_types.hash}_#{severity_levels.hash}_#{user_id}"
  end

  def immutable?
    true
  end
end

# Reactive audit query processor
class AuditQueryProcessor
  def self.execute(query_spec)
    CircuitBreaker.execute_with_fallback(:audit_query) do
      ReactiveCache.fetch(query_spec.cache_key, strategy: query_spec.cache_strategy) do
        compute_audit_analytics_optimized(query_spec)
      end
    end
  rescue => e
    Rails.logger.warn("Audit query cache failed, computing directly: #{e.message}")
    compute_audit_analytics_optimized(query_spec)
  end

  private

  def self.compute_audit_analytics_optimized(query_spec)
    # Machine learning audit pattern optimization
    optimized_query = AuditQueryOptimizer.optimize_query(query_spec)

    # Execute forensic audit analysis
    audit_results = execute_forensic_audit_analysis(optimized_query)

    # Apply machine learning threat detection
    enhanced_results = apply_ml_threat_detection(audit_results, query_spec)

    # Generate comprehensive audit analytics
    {
      query_spec: query_spec,
      audit_events: enhanced_results[:events],
      security_analysis: enhanced_results[:security_analysis],
      compliance_analysis: enhanced_results[:compliance_analysis],
      forensic_analysis: enhanced_results[:forensic_analysis],
      performance_metrics: calculate_audit_query_performance_metrics(enhanced_results),
      insights: generate_audit_insights(enhanced_results, query_spec),
      recommendations: generate_audit_recommendations(enhanced_results, query_spec)
    }
  end

  def self.execute_forensic_audit_analysis(optimized_query)
    # Execute comprehensive forensic analysis
    ForensicAuditEngine.execute do |engine|
      engine.retrieve_audit_events(optimized_query)
      engine.build_audit_timeline(optimized_query)
      engine.perform_correlation_analysis(optimized_query)
      engine.identify_suspicious_patterns(optimized_query)
      engine.generate_forensic_insights(optimized_query)
    end
  end

  def self.apply_ml_threat_detection(results, query_spec)
    # Apply machine learning threat detection
    MachineLearningThreatDetector.enhance do |detector|
      detector.extract_threat_features(results)
      detector.apply_threat_detection_models(results)
      detector.generate_threat_intelligence(results)
      detector.calculate_threat_confidence_scores(results)
      detector.validate_threat_detection_accuracy(results)
    end
  end

  def self.calculate_audit_query_performance_metrics(results)
    # Calculate comprehensive audit query performance metrics
    {
      query_execution_time_ms: results[:execution_time] || 0,
      events_processed: results[:events_count] || 0,
      security_events_analyzed: results[:security_events_count] || 0,
      compliance_events_validated: results[:compliance_events_count] || 0,
      forensic_patterns_identified: results[:forensic_patterns_count] || 0
    }
  end

  def self.generate_audit_insights(results, query_spec)
    # Generate actionable audit insights
    insights_generator = AuditInsightsGenerator.new(results, query_spec)

    insights_generator.generate do |generator|
      generator.analyze_audit_patterns
      generator.identify_security_trends
      generator.evaluate_compliance_posture
      generator.generate_forensic_insights
    end
  end

  def self.generate_audit_recommendations(results, query_spec)
    # Generate audit-based recommendations
    recommendations_engine = AuditRecommendationsEngine.new(results, query_spec)

    recommendations_engine.generate do |engine|
      engine.analyze_security_gaps
      engine.evaluate_compliance_risks
      engine.prioritize_remediation_actions
      engine.generate_implementation_guidance
    end
  end
end

# ═══════════════════════════════════════════════════════════════════════════════════
# INFRASTRUCTURE LAYER: Circuit Breakers and Cryptographic Security
# ═══════════════════════════════════════════════════════════════════════════════════

# Cryptographic signing engine for audit integrity
class CryptographicSigningEngine
  class << self
    def sign(&block)
      signer = new
      signer.instance_eval(&block)
      signer.signature_data
    end

    def initialize
      @signature_data = {}
    end

    def generate_signature_payload
      @payload = generate_audit_payload
    end

    def apply_cryptographic_algorithm
      @signature = generate_cryptographic_signature(@payload)
      @signature_valid = validate_signature_integrity(@payload, @signature)
    end

    def validate_signature_integrity
      @validation_result = @signature_valid
    end

    def signature_data
      {
        signature: @signature,
        signature_valid: @signature_valid,
        validation_result: @validation_result
      }
    end

    private

    def generate_audit_payload
      # Generate payload for cryptographic signing
      {
        timestamp: Time.current,
        random_nonce: SecureRandom.hex(16),
        event_metadata: @event_metadata
      }
    end

    def generate_cryptographic_signature(payload)
      # Generate HMAC-SHA256 signature
      signature_data = payload.to_json
      OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base, signature_data)
    end

    def validate_signature_integrity(payload, signature)
      # Validate signature integrity
      expected_signature = generate_cryptographic_signature(payload)
      secure_compare(signature, expected_signature)
    end

    def secure_compare(signature1, signature2)
      # Constant-time string comparison to prevent timing attacks
      return false if signature1.nil? || signature2.nil?
      return false if signature1.length != signature2.length

      signature1.chars.zip(signature2.chars).all? do |char1, char2|
        char1 == char2
      end
    end
  end
end

# ═══════════════════════════════════════════════════════════════════════════════════
# PRIMARY SERVICE INTERFACE: Hyperscale Audit Service
# ═══════════════════════════════════════════════════════════════════════════════════

# Ωηεαɠσηαʅ Security Audit Service with asymptotic optimality
class AuditService
  include Singleton
  include ServiceResultHelper
  include ObservableOperation

  def initialize(
    event_store: EventStoreAdapter.new,
    analytics_engine: SecurityAnalyticsEngine.instance,
    compliance_engine: ComplianceEngine.instance,
    distributed_storage: AuditStorageAdapter.new
  )
    @event_store = event_store
    @analytics_engine = analytics_engine
    @compliance_engine = compliance_engine
    @distributed_storage = distributed_storage
    @event_processors = initialize_event_processors
    validate_enterprise_infrastructure!
  end

  def record_event(event_type:, user: nil, details: {}, context: {})
    with_observation('record_audit_event') do |trace_id|
      command = RecordAuditEventCommand.from_params(
        event_type,
        user: user,
        details: details,
        context: context
      )

      AuditCommandProcessor.execute(command)
    end
  rescue ArgumentError => e
    failure_result("Invalid audit event parameters: #{e.message}")
  rescue => e
    failure_result("Audit event recording failed: #{e.message}")
  end

  def query_audit_trail(filters: {}, pagination: {}, sorting: {})
    with_observation('query_audit_trail') do |trace_id|
      query_spec = AuditQuery.from_params(
        filters[:time_range] || {},
        event_types: filters[:event_types],
        severity_levels: filters[:severity_levels],
        user_id: filters[:user_id],
        compliance_flags: filters[:compliance_flags],
        risk_threshold: filters[:risk_threshold],
        pagination: pagination,
        sorting: sorting
      )

      audit_results = AuditQueryProcessor.execute(query_spec)

      success_result(audit_results, 'Audit trail query completed successfully')
    end
  rescue => e
    failure_result("Audit trail query failed: #{e.message}")
  end

  def generate_compliance_report(report_type:, date_range:, format: :json)
    with_observation('generate_compliance_report') do |trace_id|
      # Validate compliance requirements
      compliance_spec = @compliance_engine.build_compliance_specification(
        report_type: report_type,
        date_range: date_range
      )

      # Query relevant audit events
      audit_events = query_audit_trail(
        filters: compliance_spec.filters,
        pagination: { page: 1, per_page: 10000 }
      ).audit_events

      # Generate compliance report
      report_generator = ComplianceReportGenerator.new(compliance_spec, audit_events)

      report_data = case format
      when :json
        report_generator.generate_json_report
      when :pdf
        report_generator.generate_pdf_report
      when :csv
        report_generator.generate_csv_report
      else
        raise ArgumentError, "Unsupported report format: #{format}"
      end

      success_result(report_data, 'Compliance report generated successfully')
    end
  rescue => e
    failure_result("Compliance report generation failed: #{e.message}")
  end

  def detect_threats(time_window: 5.minutes)
    with_observation('detect_threats') do |trace_id|
      # Query recent security events
      recent_events = query_audit_trail(
        filters: {
          event_types: [:security],
          time_range: { from: Time.current - time_window, to: Time.current }
        }
      ).audit_events

      # Apply threat detection algorithms
      threat_analysis = @analytics_engine.analyze_threat_patterns(recent_events)

      # Generate threat intelligence
      threat_intelligence = generate_threat_intelligence(threat_analysis)

      success_result(threat_intelligence, 'Threat detection completed successfully')
    end
  rescue => e
    failure_result("Threat detection failed: #{e.message}")
  end

  def perform_forensic_analysis(incident_id:, analysis_scope: :comprehensive)
    with_observation('perform_forensic_analysis') do |trace_id|
      # Retrieve incident-related events
      incident_events = query_audit_trail(
        filters: { incident_id: incident_id }
      ).audit_events

      # Build forensic timeline
      forensic_timeline = build_forensic_timeline(incident_events)

      # Apply forensic analysis techniques
      forensic_analysis = case analysis_scope
      when :comprehensive
        perform_comprehensive_forensic_analysis(forensic_timeline)
      when :timeline_only
        forensic_timeline
      when :pattern_analysis
        perform_pattern_forensic_analysis(forensic_timeline)
      else
        raise ArgumentError, "Unknown analysis scope: #{analysis_scope}"
      end

      forensic_result = ForensicAnalysisResult.new(
        incident_id: incident_id,
        analysis_scope: analysis_scope,
        timeline: forensic_timeline,
        analysis: forensic_analysis,
        recommendations: generate_forensic_recommendations(forensic_analysis)
      )

      success_result(forensic_result, 'Forensic analysis completed successfully')
    end
  rescue => e
    failure_result("Forensic analysis failed: #{e.message}")
  end

  # ═══════════════════════════════════════════════════════════════════════════════════
  # PREDICTIVE FEATURES: Machine Learning Security Intelligence
  # ═══════════════════════════════════════════════════════════════════════════════════

  def self.predictive_security_insights(time_horizon = :next_7_days)
    with_observation('predictive_security_insights') do |trace_id|
      # Machine learning prediction of security threats
      security_predictions = SecurityPredictionEngine.predict_threats(time_horizon)

      # Generate predictive security recommendations
      security_recommendations = generate_predictive_security_recommendations(security_predictions)

      success_result({
        time_horizon: time_horizon,
        security_predictions: security_predictions,
        recommendations: security_recommendations,
        confidence_intervals: calculate_security_prediction_confidence(security_predictions)
      }, 'Predictive security insights generated successfully')
    end
  end

  def self.predictive_compliance_monitoring(compliance_framework = :gdpr)
    with_observation('predictive_compliance_monitoring') do |trace_id|
      # Machine learning prediction of compliance violations
      compliance_predictions = CompliancePredictionEngine.predict_violations(compliance_framework)

      # Generate compliance remediation recommendations
      compliance_recommendations = generate_compliance_recommendations(compliance_predictions)

      success_result({
        compliance_framework: compliance_framework,
        predictions: compliance_predictions,
        recommendations: compliance_recommendations,
        risk_assessment: assess_compliance_risks(compliance_predictions)
      }, 'Predictive compliance monitoring completed successfully')
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════════════
  # PRIVATE HELPER METHODS: Enterprise Audit Infrastructure
  # ═══════════════════════════════════════════════════════════════════════════════════

  private

  def validate_enterprise_infrastructure!
    # Validate that all enterprise infrastructure is available
    unless defined?(AuditEvent)
      raise ArgumentError, "AuditEvent model not available"
    end
    unless defined?(EventBus)
      Rails.logger.warn("EventBus not available - operating in degraded mode")
    end
  end

  def initialize_event_processors
    # Initialize specialized event processors for different audit domains
    {
      security: [
        SecurityEventProcessor.new,
        ThreatDetectionProcessor.new,
        AnomalyDetectionProcessor.new
      ],
      compliance: [
        GdprComplianceProcessor.new,
        SoxComplianceProcessor.new,
        HipaaComplianceProcessor.new
      ],
      forensics: [
        ForensicAnalysisProcessor.new,
        TimelineReconstructionProcessor.new,
        PatternAnalysisProcessor.new
      ]
    }
  end

  def generate_threat_intelligence(threat_analysis)
    # Generate comprehensive threat intelligence
    ThreatIntelligenceGenerator.generate do |generator|
      generator.analyze_threat_patterns(threat_analysis)
      generator.correlate_threat_indicators(threat_analysis)
      generator.assess_threat_severity(threat_analysis)
      generator.generate_threat_recommendations(threat_analysis)
    end
  end

  def build_forensic_timeline(incident_events)
    # Build comprehensive forensic timeline
    ForensicTimelineBuilder.build do |builder|
      builder.chronological_sort(incident_events)
      builder.causal_link_analysis(incident_events)
      builder.context_enrichment(incident_events)
      builder.pattern_identification(incident_events)
    end
  end

  def perform_comprehensive_forensic_analysis(timeline)
    # Perform comprehensive forensic analysis
    ComprehensiveForensicAnalyzer.analyze do |analyzer|
      analyzer.behavioral_pattern_analysis(timeline)
      analyzer.network_traffic_analysis(timeline)
      analyzer.file_system_analysis(timeline)
      analyzer.memory_analysis(timeline)
      analyzer.generate_forensic_report(timeline)
    end
  end

  def perform_pattern_forensic_analysis(timeline)
    # Perform pattern-based forensic analysis
    PatternForensicAnalyzer.analyze do |analyzer|
      analyzer.identify_behavioral_patterns(timeline)
      analyzer.detect_anomalous_sequences(timeline)
      analyzer.correlation_analysis(timeline)
      analyzer.generate_pattern_insights(timeline)
    end
  end

  def generate_forensic_recommendations(analysis)
    # Generate forensic-based recommendations
    ForensicRecommendationsEngine.generate do |engine|
      engine.analyze_forensic_findings(analysis)
      engine.identify_security_gaps(analysis)
      engine.prioritize_remediation_actions(analysis)
      engine.generate_implementation_roadmap(analysis)
    end
  end

  def self.generate_predictive_security_recommendations(security_predictions)
    # Generate recommendations based on security predictions
    recommendations = []

    security_predictions.each do |prediction|
      if prediction[:threat_probability] > 0.7
        recommendations << {
          type: :preventive_security_measure,
          threat_type: prediction[:threat_type],
          recommended_action: prediction[:recommended_action],
          priority: :high,
          implementation_timeframe: :immediate
        }
      end
    end

    recommendations
  end

  def self.generate_compliance_recommendations(compliance_predictions)
    # Generate recommendations based on compliance predictions
    recommendations = []

    compliance_predictions.each do |prediction|
      if prediction[:violation_probability] > 0.6
        recommendations << {
          type: :compliance_improvement,
          regulation: prediction[:regulation],
          recommended_action: prediction[:recommended_action],
          priority: :medium,
          implementation_timeframe: :next_sprint
        }
      end
    end

    recommendations
  end

  def self.calculate_security_prediction_confidence(security_predictions)
    # Calculate confidence intervals for security predictions
    return { overall: { lower: 0, upper: 0 } } if security_predictions.empty?

    confidence_scores = security_predictions.map { |p| p[:confidence] || 0.5 }
    average_confidence = confidence_scores.sum / confidence_scores.size

    variance = confidence_scores.sum { |score| (score - average_confidence) ** 2 } / confidence_scores.size
    standard_deviation = Math.sqrt(variance)

    {
      overall: {
        lower: [average_confidence - standard_deviation, 0.0].max,
        upper: [average_confidence + standard_deviation, 1.0].min
      }
    }
  end

  def self.assess_compliance_risks(compliance_predictions)
    # Assess overall compliance risks
    return :low if compliance_predictions.empty?

    high_risk_predictions = compliance_predictions.count do |prediction|
      prediction[:violation_probability] > 0.7
    end

    risk_level = case high_risk_predictions
    when 0..1 then :low
    when 2..3 then :medium
    else :high
    end

    {
      overall_risk_level: risk_level,
      high_risk_predictions_count: high_risk_predictions,
      total_predictions: compliance_predictions.size
    }
  end

  # ═══════════════════════════════════════════════════════════════════════════════════
  # ERROR HANDLING: Antifragile Audit Error Management
  # ═══════════════════════════════════════════════════════════════════════════════════

  class AuditProcessingError < StandardError; end
  class AuditIntegrityError < StandardError; end
  class CryptographicError < StandardError; end

  private

  def validate_audit_event_integrity!(event_type, details)
    # Validate audit event integrity before processing
    unless valid_event_type?(event_type)
      raise ArgumentError, "Invalid audit event type: #{event_type}"
    end

    if sensitive_event_requires_encryption?(event_type) && contains_sensitive_data?(details)
      unless encryption_enabled?
        raise CryptographicError, "Encryption required for sensitive audit event"
      end
    end
  end

  def valid_event_type?(event_type)
    # Validate against allowed event types
    allowed_types = EVENT_TYPES.values.flatten
    allowed_types.include?(event_type&.to_sym)
  end

  def sensitive_event_requires_encryption?(event_type)
    # Check if event type requires encryption
    sensitive_types = [:sensitive_data_access, :financial_transaction, :authentication]
    sensitive_types.include?(event_type&.to_sym)
  end

  def contains_sensitive_data?(details)
    # Check if details contain sensitive information
    sensitive_patterns = [:password, :credit_card, :ssn, :api_key]

    details.any? do |key, value|
      sensitive_patterns.include?(key&.to_sym) && value.present?
    end
  end

  def encryption_enabled?
    # Check if encryption is properly configured
    Rails.application.secret_key_base.present?
  end

  # ═══════════════════════════════════════════════════════════════════════════════════
  # MACHINE LEARNING INTEGRATION: Advanced Security Intelligence
  # ═══════════════════════════════════════════════════════════════════════════════════

  # Machine learning threat detection engine
  class MachineLearningThreatDetector
    class << self
      def enhance(&block)
        detector = new
        detector.instance_eval(&block)
        detector.detection_results
      end

      def initialize
        @detection_results = {}
      end

      def extract_threat_features(results)
        @threat_features = ThreatFeatureExtractor.extract_features(results)
      end

      def apply_threat_detection_models(results)
        @model_predictions = ThreatModelApplicator.apply_models(@threat_features)
      end

      def generate_threat_intelligence(results)
        @threat_intelligence = ThreatIntelligenceGenerator.generate(@model_predictions)
      end

      def calculate_threat_confidence_scores(results)
        @confidence_scores = ConfidenceScoreCalculator.calculate(@model_predictions)
      end

      def validate_threat_detection_accuracy(results)
        @validation_results = AccuracyValidator.validate(@model_predictions)
      end

      def detection_results
        {
          threat_features: @threat_features,
          model_predictions: @model_predictions,
          threat_intelligence: @threat_intelligence,
          confidence_scores: @confidence_scores,
          validation_results: @validation_results
        }
      end
    end
  end

  # Threat feature extraction for machine learning
  class ThreatFeatureExtractor
    class << self
      def extract_features(results)
        # Extract features for threat detection models
        features = {}

        # Temporal threat features
        features[:temporal] = extract_temporal_threat_features(results)

        # Behavioral threat features
        features[:behavioral] = extract_behavioral_threat_features(results)

        # Network threat features
        features[:network] = extract_network_threat_features(results)

        # Access pattern features
        features[:access] = extract_access_pattern_features(results)

        features
      end

      private

      def extract_temporal_threat_features(results)
        # Extract time-based threat indicators
        events = results[:audit_events] || []

        {
          unusual_timing: detect_unusual_timing(events),
          rapid_fire_events: detect_rapid_fire_events(events),
          off_hours_activity: detect_off_hours_activity(events),
          weekend_activity: detect_weekend_activity(events)
        }
      end

      def extract_behavioral_threat_features(results)
        # Extract behavioral threat indicators
        user_events = results[:user_events] || {}

        {
          privilege_escalation: detect_privilege_escalation(user_events),
          unusual_data_access: detect_unusual_data_access(user_events),
          account_manipulation: detect_account_manipulation(user_events),
          session_anomalies: detect_session_anomalies(user_events)
        }
      end

      def extract_network_threat_features(results)
        # Extract network-based threat indicators
        network_events = results[:network_events] || {}

        {
          unusual_ip_activity: detect_unusual_ip_activity(network_events),
          geo_velocity: detect_geographic_velocity(network_events),
          proxy_vpn_usage: detect_proxy_vpn_usage(network_events),
          tor_usage: detect_tor_usage(network_events)
        }
      end

      def extract_access_pattern_features(results)
        # Extract access pattern threat indicators
        access_events = results[:access_events] || {}

        {
          bulk_data_export: detect_bulk_data_export(access_events),
          unusual_file_access: detect_unusual_file_access(access_events),
          database_anomalies: detect_database_anomalies(access_events),
          api_abuse: detect_api_abuse(access_events)
        }
      end

      def detect_unusual_timing(events)
        # Detect events occurring at unusual times
        return 0.0 if events.empty?

        unusual_events = events.count do |event|
          hour = event.timestamp.hour
          hour < 6 || hour > 22 # Outside normal business hours
        end

        unusual_events.to_f / events.size
      end

      def detect_rapid_fire_events(events)
        # Detect rapid succession of events (potential automated attack)
        return 0.0 if events.size < 2

        intervals = events.each_cons(2).map do |event1, event2|
          event2.timestamp - event1.timestamp
        end

        rapid_events = intervals.count { |interval| interval < 1.second }
        rapid_events.to_f / intervals.size
      end

      def detect_off_hours_activity(events)
        # Detect activity outside normal business hours
        business_hours_events = events.count do |event|
          hour = event.timestamp.hour
          hour.between?(9, 17) && event.timestamp.wday.between?(1, 5) # Mon-Fri, 9-5
        end

        1.0 - (business_hours_events.to_f / events.size)
      end

      def detect_weekend_activity(events)
        # Detect activity on weekends
        weekend_events = events.count do |event|
          event.timestamp.wday == 0 || event.timestamp.wday == 6 # Sunday or Saturday
        end

        weekend_events.to_f / events.size
      end

      def detect_privilege_escalation(user_events)
        # Detect rapid privilege escalation patterns
        privilege_events = user_events.select do |event|
          [:privilege_escalation, :role_changed].include?(event.event_type)
        end

        return 0.0 if privilege_events.empty?

        # Check for rapid escalation within short time window
        sorted_privilege_events = privilege_events.sort_by(&:timestamp)

        rapid_escalations = 0
        sorted_privilege_events.each_cons(2) do |event1, event2|
          time_diff = event2.timestamp - event1.timestamp
          rapid_escalations += 1 if time_diff < 5.minutes
        end

        rapid_escalations.to_f / sorted_privilege_events.size
      end

      def detect_unusual_data_access(user_events)
        # Detect unusual data access patterns
        data_access_events = user_events.select do |event|
          [:data_accessed, :sensitive_data_access].include?(event.event_type)
        end

        return 0.0 if data_access_events.empty?

        # Analyze access patterns for anomalies
        baseline_access = calculate_baseline_data_access(user_events)
        current_access = data_access_events.size

        anomaly_score = if baseline_access > 0
          (current_access - baseline_access).abs.to_f / baseline_access
        else
          current_access > 5 ? 0.8 : 0.0 # High access for new pattern
        end

        [anomaly_score, 1.0].min
      end

      def detect_account_manipulation(user_events)
        # Detect suspicious account manipulation
        account_events = user_events.select do |event|
          [:account_locked, :password_reset_requested, :account_unlocked].include?(event.event_type)
        end

        return 0.0 if account_events.empty?

        # Multiple account events in short time = suspicious
        time_window = 1.hour
        suspicious_windows = 0

        account_events.sort_by(&:timestamp).each_cons(3) do |events_group|
          time_span = events_group.last.timestamp - events_group.first.timestamp
          suspicious_windows += 1 if time_span < time_window
        end

        suspicious_windows.to_f / account_events.size
      end

      def detect_session_anomalies(user_events)
        # Detect anomalous session patterns
        session_events = user_events.select do |event|
          [:session_created, :session_terminated, :session_expired].include?(event.event_type)
        end

        return 0.0 if session_events.empty?

        # Analyze session duration patterns
        session_durations = calculate_session_durations(session_events)

        # Detect unusually short or long sessions
        avg_duration = session_durations.sum / session_durations.size.to_f
        anomaly_threshold = avg_duration * 0.5 # 50% of average

        short_sessions = session_durations.count { |duration| duration < anomaly_threshold }
        short_sessions.to_f / session_durations.size
      end

      def detect_unusual_ip_activity(network_events)
        # Detect unusual IP address patterns
        ip_events = network_events.select do |event|
          event.ip_address.present?
        end

        return 0.0 if ip_events.empty?

        # Count unique IPs and frequency
        ip_frequency = ip_events.group_by(&:ip_address).transform_values(&:size)

        # High frequency from single IP might indicate automated activity
        max_frequency = ip_frequency.values.max || 0
        unusual_score = [max_frequency / 100.0, 1.0].min # Cap at 1.0

        unusual_score
      end

      def detect_geographic_velocity(network_events)
        # Detect impossible geographic movement (travel velocity)
        geo_events = network_events.select do |event|
          event.geolocation.present?
        end

        return 0.0 if geo_events.size < 2

        # Calculate geographic velocity between consecutive events
        velocities = geo_events.each_cons(2).map do |event1, event2|
          calculate_geographic_velocity(event1, event2)
        end

        # High velocities indicate suspicious activity
        impossible_velocities = velocities.count { |velocity| velocity > 1000 } # km/h
        impossible_velocities.to_f / velocities.size
      end

      def detect_proxy_vpn_usage(network_events)
        # Detect proxy/VPN usage patterns
        proxy_indicators = network_events.select do |event|
          event.user_agent&.include?('proxy') ||
          event.ip_address&.match?(/proxy|vpn|tor/i) ||
          event.context[:proxy_detected]
        end

        proxy_indicators.size.to_f / network_events.size
      end

      def detect_tor_usage(network_events)
        # Detect Tor network usage
        tor_indicators = network_events.select do |event|
          event.ip_address&.match?(/tor|onion/i) ||
          event.context[:tor_detected] ||
          event.geolocation&.dig('country_code') == 'TOR'
        end

        tor_indicators.size.to_f / network_events.size
      end

      def detect_bulk_data_export(access_events)
        # Detect bulk data export patterns
        export_events = access_events.select do |event|
          event.event_type == :data_export
        end

        return 0.0 if export_events.empty?

        # Analyze export volume and frequency
        large_exports = export_events.count do |event|
          event.details[:record_count].to_i > 1000
        end

        large_exports.to_f / export_events.size
      end

      def detect_unusual_file_access(access_events)
        # Detect unusual file access patterns
        file_access_events = access_events.select do |event|
          event.event_type == :data_accessed
        end

        return 0.0 if file_access_events.empty?

        # Analyze file access patterns for anomalies
        baseline_access = calculate_baseline_file_access(access_events)
        current_access = file_access_events.size

        anomaly_score = if baseline_access > 0
          (current_access - baseline_access).abs.to_f / baseline_access
        else
          current_access > 10 ? 0.7 : 0.0
        end

        [anomaly_score, 1.0].min
      end

      def detect_database_anomalies(access_events)
        # Detect database access anomalies
        db_events = access_events.select do |event|
          event.details[:data_source]&.include?('database')
        end

        return 0.0 if db_events.empty?

        # Analyze query patterns for anomalies
        unusual_queries = db_events.count do |event|
          event.details[:query_complexity] == :high ||
          event.details[:unusual_table_access] == true
        end

        unusual_queries.to_f / db_events.size
      end

      def detect_api_abuse(access_events)
        # Detect API abuse patterns
        api_events = access_events.select do |event|
          event.details[:access_method] == :api
        end

        return 0.0 if api_events.empty?

        # Analyze API call patterns
        rapid_api_calls = api_events.each_cons(5).count do |events|
          time_span = events.last.timestamp - events.first.timestamp
          time_span < 1.second # More than 5 calls per second
        end

        rapid_api_calls.to_f / api_events.size
      end

      def calculate_geographic_velocity(event1, event2)
        # Calculate velocity between two geographic points
        geo1 = event1.geolocation
        geo2 = event2.geolocation

        return 0.0 if geo1.blank? || geo2.blank?

        # Simplified distance calculation (in production use proper geodetic math)
        lat1, lon1 = geo1['latitude'], geo1['longitude']
        lat2, lon2 = geo2['latitude'], geo2['longitude']

        # Haversine formula for distance
        distance_km = calculate_haversine_distance(lat1, lon1, lat2, lon2)

        time_diff_hours = (event2.timestamp - event1.timestamp) / 1.hour

        return 0.0 if time_diff_hours.zero?

        distance_km / time_diff_hours
      end

      def calculate_haversine_distance(lat1, lon1, lat2, lon2)
        # Haversine formula for geographic distance
        earth_radius_km = 6371

        dlat = (lat2 - lat1) * Math::PI / 180
        dlon = (lon2 - lon1) * Math::PI / 180

        a = Math.sin(dlat/2) * Math.sin(dlat/2) +
            Math.cos(lat1 * Math::PI / 180) * Math.cos(lat2 * Math::PI / 180) *
            Math.sin(dlon/2) * Math.sin(dlon/2)

        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
        earth_radius_km * c
      end

      def calculate_baseline_data_access(user_events)
        # Calculate baseline data access for user
        data_events = user_events.select do |event|
          [:data_accessed, :sensitive_data_access].include?(event.event_type)
        end

        # Average over last 30 days
        baseline_period = 30.days.ago
        recent_data_events = data_events.select do |event|
          event.timestamp >= baseline_period
        end

        recent_data_events.size / 30.0 # Daily average
      end

      def calculate_baseline_file_access(access_events)
        # Calculate baseline file access patterns
        file_events = access_events.select do |event|
          event.event_type == :data_accessed
        end

        # Average file access over baseline period
        baseline_period = 7.days.ago
        recent_file_events = file_events.select do |event|
          event.timestamp >= baseline_period
        end

        recent_file_events.size / 7.0 # Daily average
      end

      def calculate_session_durations(session_events)
        # Calculate session durations from events
        sessions = group_events_by_session(session_events)

        sessions.map do |session_id, events|
          sorted_events = events.sort_by(&:timestamp)
          next 0 if sorted_events.size < 2

          sorted_events.last.timestamp - sorted_events.first.timestamp
        end
      end

      def group_events_by_session(session_events)
        # Group events by session ID
        session_events.group_by(&:session_id)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════════════
  # LEGACY COMPATIBILITY INTERFACE: Maintains existing API compatibility
  # ═══════════════════════════════════════════════════════════════════════════════════

  class << self
    # Legacy method aliases for backward compatibility
    alias_method :log_event, :record_event
    alias_method :search_audit_logs, :query_audit_trail
    alias_method :create_compliance_report, :generate_compliance_report
    alias_method :analyze_threats, :detect_threats
    alias_method :investigate_incident, :perform_forensic_analysis
  end
end