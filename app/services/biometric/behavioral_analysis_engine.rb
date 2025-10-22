# Advanced Behavioral Analysis Engine for Biometric Authentication
# Analyzes user behavior patterns, device interactions, and authentication habits
#
# Features: Pattern recognition, anomaly detection, trust scoring, session analysis
# Performance: Real-time behavioral analysis with predictive modeling

class BehavioralAnalysisEngine
  include Analytics::PatternRecognition
  include MachineLearning::BehavioralModels

  # =============================================
  # BEHAVIORAL ANALYSIS WORKFLOW
  # =============================================

  def initialize(biometric_authentication)
    @authentication = biometric_authentication
    @user = biometric_authentication.user
    @device = biometric_authentication.mobile_device
    @pattern_analyzer = UserPatternAnalyzer.new(@user)
    @risk_calculator = BehavioralRiskCalculator.new
    @ml_models = load_behavioral_models
  end

  def analyze_session_patterns(context)
    # Comprehensive behavioral analysis pipeline
    behavioral_data = extract_behavioral_features(context)

    # Pattern recognition across multiple dimensions
    pattern_analysis = analyze_behavioral_patterns(behavioral_data)

    # Risk assessment based on deviations
    risk_assessment = assess_behavioral_risks(pattern_analysis, context)

    # Generate behavioral profile update
    profile_update = generate_behavioral_profile_update(pattern_analysis)

    # Return comprehensive analysis result
    BehavioralAnalysisResult.new(
      anomaly_score: risk_assessment.anomaly_score,
      confidence: risk_assessment.confidence,
      behavioral_patterns: pattern_analysis,
      risk_factors: risk_assessment.risk_factors,
      profile_update: profile_update,
      recommendations: generate_behavioral_recommendations(risk_assessment)
    )
  end

  def analyze_historical_patterns(time_window: 30.days)
    # Analyze user's historical authentication patterns
    historical_data = fetch_historical_behavioral_data(time_window)

    # Identify consistent patterns
    consistent_patterns = identify_consistent_patterns(historical_data)

    # Detect behavioral drift
    behavioral_drift = detect_behavioral_drift(historical_data, consistent_patterns)

    # Generate behavioral baseline
    behavioral_baseline = generate_behavioral_baseline(consistent_patterns)

    {
      consistent_patterns: consistent_patterns,
      behavioral_drift: behavioral_drift,
      baseline: behavioral_baseline,
      analysis_timestamp: Time.current.utc
    }
  end

  def validate_device_integrity(device_info:, historical_device_data:)
    integrity_checks = []

    # Check device fingerprint consistency
    fingerprint_check = validate_device_fingerprint(device_info, historical_device_data)
    integrity_checks << fingerprint_check

    # Check device behavior patterns
    behavior_check = validate_device_behavior_patterns(device_info, historical_device_data)
    integrity_checks << behavior_check

    # Check for device spoofing indicators
    spoofing_check = detect_device_spoofing_indicators(device_info)
    integrity_checks << spoofing_check

    # Aggregate integrity score
    integrity_score = calculate_integrity_score(integrity_checks)

    DeviceIntegrityResult.new(
      integrity_score: integrity_score,
      confidence: calculate_integrity_confidence(integrity_checks),
      issues: extract_integrity_issues(integrity_checks),
      checks_performed: integrity_checks.map(&:type)
    )
  end

  private

  # =============================================
  # BEHAVIORAL FEATURE EXTRACTION
  # =============================================

  def extract_behavioral_features(context)
    features = {}

    # Temporal behavior features
    features[:temporal] = extract_temporal_behavior(context)

    # Interaction behavior features
    features[:interaction] = extract_interaction_behavior(context)

    # Device behavior features
    features[:device] = extract_device_behavior(context)

    # Authentication behavior features
    features[:authentication] = extract_authentication_behavior(context)

    # Environmental behavior features
    features[:environmental] = extract_environmental_behavior(context)

    features
  end

  def extract_temporal_behavior(context)
    {
      hour_of_day: context[:timestamp]&.hour,
      day_of_week: context[:timestamp]&.wday,
      time_of_month: context[:timestamp]&.day,
      season: determine_season(context[:timestamp]),
      is_holiday: holiday_context?(context[:timestamp]),
      time_since_last_activity: calculate_time_since_last_activity(context),
      session_duration: context[:session_duration],
      typing_speed: extract_typing_speed(context),
      navigation_patterns: extract_navigation_patterns(context)
    }
  end

  def extract_interaction_behavior(context)
    interaction_data = context[:interaction_data] || {}

    {
      touch_patterns: interaction_data[:touch_patterns],
      swipe_gestures: interaction_data[:swipe_gestures],
      pressure_patterns: interaction_data[:pressure_patterns],
      accelerometer_data: interaction_data[:accelerometer_data],
      gyroscope_data: interaction_data[:gyroscope_data],
      screen_orientation_changes: interaction_data[:orientation_changes],
      app_switching_frequency: interaction_data[:app_switches],
      idle_time_patterns: interaction_data[:idle_times]
    }
  end

  def extract_device_behavior(context)
    device_info = context[:device_info] || {}

    {
      device_orientation: device_info[:orientation],
      screen_brightness: device_info[:brightness],
      volume_level: device_info[:volume],
      connectivity_status: device_info[:connectivity],
      battery_level: device_info[:battery_level],
      charging_status: device_info[:charging],
      location_services_enabled: device_info[:location_enabled],
      biometric_settings: device_info[:biometric_settings]
    }
  end

  def extract_authentication_behavior(context)
    {
      authentication_method: context[:auth_method],
      authentication_duration: context[:auth_duration],
      success_fail_pattern: context[:success_fail_pattern],
      retry_attempts: context[:retry_count],
      hesitation_patterns: context[:hesitation_times],
      error_patterns: context[:error_types],
      authentication_frequency: calculate_auth_frequency(context)
    }
  end

  def extract_environmental_behavior(context)
    {
      location_consistency: calculate_location_consistency(context),
      network_consistency: calculate_network_consistency(context),
      ip_reputation: context[:ip_reputation],
      geolocation_risk: context[:geolocation_risk],
      time_zone_consistency: check_time_zone_consistency(context),
      language_settings: context[:language_settings]
    }
  end

  # =============================================
  # PATTERN ANALYSIS
  # =============================================

  def analyze_behavioral_patterns(behavioral_data)
    patterns = {}

    # Analyze temporal patterns
    patterns[:temporal] = analyze_temporal_patterns(behavioral_data[:temporal])

    # Analyze interaction patterns
    patterns[:interaction] = analyze_interaction_patterns(behavioral_data[:interaction])

    # Analyze device patterns
    patterns[:device] = analyze_device_patterns(behavioral_data[:device])

    # Analyze authentication patterns
    patterns[:authentication] = analyze_authentication_patterns(behavioral_data[:authentication])

    # Cross-pattern correlation
    patterns[:correlations] = analyze_pattern_correlations(patterns)

    patterns
  end

  def analyze_temporal_patterns(temporal_data)
    @pattern_analyzer.analyze_temporal_patterns(temporal_data)
  end

  def analyze_interaction_patterns(interaction_data)
    @pattern_analyzer.analyze_interaction_patterns(interaction_data)
  end

  def analyze_device_patterns(device_data)
    @pattern_analyzer.analyze_device_patterns(device_data)
  end

  def analyze_authentication_patterns(auth_data)
    @pattern_analyzer.analyze_authentication_patterns(auth_data)
  end

  def analyze_pattern_correlations(patterns)
    # Analyze correlations between different pattern types
    correlations = {}

    # Example: Check if unusual timing correlates with unusual interaction patterns
    temporal_pattern = patterns[:temporal][:normality_score] || 1.0
    interaction_pattern = patterns[:interaction][:normality_score] || 1.0

    correlations[:temporal_interaction] = calculate_correlation_strength(
      temporal_pattern,
      interaction_pattern
    )

    correlations
  end

  # =============================================
  # RISK ASSESSMENT
  # =============================================

  def assess_behavioral_risks(pattern_analysis, context)
    risk_factors = []

    # Assess temporal risks
    temporal_risk = assess_temporal_risks(pattern_analysis[:temporal], context)
    risk_factors.concat(temporal_risk)

    # Assess interaction risks
    interaction_risk = assess_interaction_risks(pattern_analysis[:interaction], context)
    risk_factors.concat(interaction_risk)

    # Assess device risks
    device_risk = assess_device_risks(pattern_analysis[:device], context)
    risk_factors.concat(device_risk)

    # Assess authentication risks
    auth_risk = assess_authentication_risks(pattern_analysis[:authentication], context)
    risk_factors.concat(auth_risk)

    # Calculate overall anomaly score
    anomaly_score = calculate_overall_anomaly_score(risk_factors)

    # Calculate confidence based on data quality and pattern strength
    confidence = calculate_risk_confidence(risk_factors, pattern_analysis)

    RiskAssessmentResult.new(
      anomaly_score: anomaly_score,
      confidence: confidence,
      risk_factors: risk_factors,
      context: context
    )
  end

  def assess_temporal_risks(temporal_patterns, context)
    risks = []

    # Check for unusual timing
    if temporal_patterns[:unusual_timing_score] > 0.7
      risks << {
        type: :unusual_timing,
        severity: :medium,
        score: temporal_patterns[:unusual_timing_score],
        description: "Authentication timing deviates from normal patterns"
      }
    end

    # Check for unusual frequency
    if temporal_patterns[:unusual_frequency_score] > 0.6
      risks << {
        type: :unusual_frequency,
        severity: :high,
        score: temporal_patterns[:unusual_frequency_score],
        description: "Authentication frequency is abnormal for this time period"
      }
    end

    risks
  end

  def assess_interaction_risks(interaction_patterns, context)
    risks = []

    # Check for unusual interaction patterns
    if interaction_patterns[:anomaly_score] > 0.8
      risks << {
        type: :unusual_interaction,
        severity: :high,
        score: interaction_patterns[:anomaly_score],
        description: "User interaction patterns are significantly different from baseline"
      }
    end

    # Check for potential automated behavior
    if interaction_patterns[:automation_score] > 0.9
      risks << {
        type: :potential_automation,
        severity: :critical,
        score: interaction_patterns[:automation_score],
        description: "Interaction patterns suggest potential automated/bot behavior"
      }
    end

    risks
  end

  def assess_device_risks(device_patterns, context)
    risks = []

    # Check for device inconsistencies
    if device_patterns[:inconsistency_score] > 0.6
      risks << {
        type: :device_inconsistency,
        severity: :medium,
        score: device_patterns[:inconsistency_score],
        description: "Device behavior is inconsistent with historical patterns"
      }
    end

    risks
  end

  def assess_authentication_risks(auth_patterns, context)
    risks = []

    # Check for unusual authentication behavior
    if auth_patterns[:hesitation_score] > 0.7
      risks << {
        type: :unusual_hesitation,
        severity: :low,
        score: auth_patterns[:hesitation_score],
        description: "User shows unusual hesitation during authentication"
      }
    end

    risks
  end

  def calculate_overall_anomaly_score(risk_factors)
    return 0.0 if risk_factors.empty?

    # Weighted average based on severity
    severity_weights = {
      critical: 1.0,
      high: 0.8,
      medium: 0.6,
      low: 0.4
    }

    weighted_scores = risk_factors.map do |factor|
      weight = severity_weights[factor[:severity]] || 0.5
      factor[:score] * weight
    end

    # Normalize to 0-1 range
    [weighted_scores.sum / risk_factors.size, 1.0].min
  end

  def calculate_risk_confidence(risk_factors, pattern_analysis)
    # Calculate confidence based on pattern strength and data quality
    pattern_strength = average_pattern_strength(pattern_analysis)
    data_quality = calculate_data_quality(risk_factors)

    (pattern_strength + data_quality) / 2.0
  end

  # =============================================
  # BEHAVIORAL PROFILE MANAGEMENT
  # =============================================

  def generate_behavioral_profile_update(pattern_analysis)
    {
      temporal_profile: pattern_analysis[:temporal][:profile],
      interaction_profile: pattern_analysis[:interaction][:profile],
      device_profile: pattern_analysis[:device][:profile],
      authentication_profile: pattern_analysis[:authentication][:profile],
      last_updated: Time.current.utc,
      confidence_score: average_pattern_strength(pattern_analysis)
    }
  end

  def generate_behavioral_recommendations(risk_assessment)
    recommendations = []

    # Generate recommendations based on risk factors
    risk_assessment.risk_factors.each do |factor|
      case factor[:type]
      when :unusual_timing
        recommendations << {
          action: :request_additional_verification,
          reason: "Unusual timing detected",
          confidence: 0.8
        }
      when :potential_automation
        recommendations << {
          action: :require_captcha_challenge,
          reason: "Potential automated behavior detected",
          confidence: 0.9
        }
      when :device_inconsistency
        recommendations << {
          action: :perform_device_reverification,
          reason: "Device behavior inconsistency",
          confidence: 0.7
        }
      end
    end

    recommendations.uniq { |r| r[:action] }
  end

  # =============================================
  # DEVICE INTEGRITY VALIDATION
  # =============================================

  def validate_device_fingerprint(device_info, historical_device_data)
    current_fingerprint = generate_device_fingerprint(device_info)
    historical_fingerprints = historical_device_data.map(&:fingerprint)

    # Check fingerprint consistency
    consistency_score = calculate_fingerprint_consistency(current_fingerprint, historical_fingerprints)

    DeviceIntegrityCheck.new(
      type: :fingerprint,
      passed: consistency_score > 0.8,
      score: consistency_score,
      details: {
        current_fingerprint: current_fingerprint,
        historical_average: average_fingerprint(historical_fingerprints)
      }
    )
  end

  def validate_device_behavior_patterns(device_info, historical_device_data)
    current_behavior = extract_device_behavior_from_info(device_info)
    historical_behavior = average_device_behavior(historical_device_data)

    # Calculate behavioral consistency
    consistency_score = calculate_behavioral_consistency(current_behavior, historical_behavior)

    DeviceIntegrityCheck.new(
      type: :behavior_pattern,
      passed: consistency_score > 0.7,
      score: consistency_score,
      details: {
        current_behavior: current_behavior,
        historical_average: historical_behavior
      }
    )
  end

  def detect_device_spoofing_indicators(device_info)
    spoofing_indicators = []

    # Check for common spoofing indicators
    spoofing_indicators << :emulator_detected if emulator_detected?(device_info)
    spoofing_indicators << :root_detected if root_detected?(device_info)
    spoofing_indicators << :hook_detected if hook_detected?(device_info)
    spoofing_indicators << :repackaged_app if repackaged_app_detected?(device_info)

    spoofing_score = spoofing_indicators.size * 0.2

    DeviceIntegrityCheck.new(
      type: :spoofing_detection,
      passed: spoofing_score < 0.3,
      score: 1.0 - spoofing_score,
      details: {
        indicators_detected: spoofing_indicators,
        spoofing_score: spoofing_score
      }
    )
  end

  def calculate_integrity_score(integrity_checks)
    # Average score across all checks
    valid_checks = integrity_checks.select(&:passed)
    return 0.0 if valid_checks.empty?

    valid_checks.sum(&:score) / valid_checks.size
  end

  def calculate_integrity_confidence(integrity_checks)
    # Confidence based on number of checks performed and their consistency
    scores = integrity_checks.map(&:score)
    return 0.0 if scores.empty?

    # Higher confidence with more checks and consistent scores
    check_count_factor = [integrity_checks.size / 5.0, 1.0].min
    consistency_factor = 1.0 - scores.variance

    (check_count_factor + consistency_factor) / 2.0
  end

  def extract_integrity_issues(integrity_checks)
    integrity_checks
      .reject(&:passed)
      .map(&:details)
  end

  # =============================================
  # UTILITY METHODS
  # =============================================

  def fetch_historical_behavioral_data(time_window)
    @authentication.verification_history
      .where('created_at >= ?', time_window.ago)
      .includes(:mobile_device)
  end

  def average_pattern_strength(pattern_analysis)
    strengths = pattern_analysis.values.map do |pattern_type|
      pattern_type[:strength_score] || 0.5
    end

    strengths.sum / strengths.size
  end

  def calculate_data_quality(risk_factors)
    # Assess quality of data used for risk assessment
    return 0.5 if risk_factors.empty?

    # More factors with higher confidence = better data quality
    avg_confidence = risk_factors.map { |f| f[:confidence] || 0.5 }.sum / risk_factors.size
    factor_diversity = risk_factors.map { |f| f[:type] }.uniq.size / 4.0

    (avg_confidence + factor_diversity) / 2.0
  end

  def generate_device_fingerprint(device_info)
    # Generate consistent device fingerprint
    components = [
      device_info[:device_id],
      device_info[:os_version],
      device_info[:app_version],
      device_info[:screen_resolution],
      device_info[:device_model]
    ].compact

    Digest::SHA256.hexdigest(components.join(':'))
  end

  def calculate_fingerprint_consistency(current, historical)
    return 1.0 if historical.empty?

    # Find closest historical match
    similarities = historical.map do |historical_fingerprint|
      calculate_string_similarity(current, historical_fingerprint)
    end

    similarities.max
  end

  def calculate_string_similarity(str1, str2)
    # Simple string similarity for demonstration
    longer = [str1.length, str2.length].max
    distance = levenshtein_distance(str1, str2)
    (longer - distance).to_f / longer
  end

  def levenshtein_distance(str1, str2)
    # Simplified Levenshtein distance calculation
    matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1, 0) }

    (0..str1.length).each { |i| matrix[i][0] = i }
    (0..str2.length).each { |j| matrix[0][j] = j }

    (1..str1.length).each do |i|
      (1..str2.length).each do |j|
        cost = (str1[i-1] == str2[j-1]) ? 0 : 1
        matrix[i][j] = [
          matrix[i-1][j] + 1,
          matrix[i][j-1] + 1,
          matrix[i-1][j-1] + cost
        ].min
      end
    end

    matrix[str1.length][str2.length]
  end

  def determine_season(timestamp)
    month = timestamp&.month
    case month
    when 3..5 then :spring
    when 6..8 then :summer
    when 9..11 then :fall
    when 12..2 then :winter
    else :unknown
    end
  end

  def holiday_context?(timestamp)
    # Check if timestamp falls on a major holiday
    # This would integrate with a holiday service
    false
  end

  def calculate_time_since_last_activity(context)
    last_activity = @user.last_activity_at || @user.last_sign_in_at
    return 24.hours if last_activity.nil?

    Time.current.utc - last_activity
  end

  def extract_typing_speed(context)
    # Extract typing speed from context if available
    context[:typing_metrics]&.dig(:speed)
  end

  def extract_navigation_patterns(context)
    # Extract navigation patterns from context
    context[:navigation_metrics]
  end

  def calculate_auth_frequency(context)
    # Calculate authentication frequency for current time period
    time_window = case context[:time_period]
    when :hour then 1.hour.ago
    when :day then 1.day.ago
    else 24.hours.ago
    end

    @authentication.verification_history
      .where('created_at >= ?', time_window)
      .count
  end

  def calculate_location_consistency(context)
    # Calculate consistency of user location patterns
    recent_locations = @authentication.verification_history
      .where('created_at >= ?', 7.days.ago)
      .pluck(:location)
      .compact

    return 1.0 if recent_locations.empty?

    # Simple consistency measure - in practice would use geographic clustering
    unique_locations = recent_locations.uniq.size
    consistency = 1.0 - (unique_locations / 10.0)
    [consistency, 0.0].max
  end

  def calculate_network_consistency(context)
    # Calculate consistency of network patterns
    recent_networks = @authentication.verification_history
      .where('created_at >= ?', 7.days.ago)
      .pluck(:ip_address)
      .compact

    return 1.0 if recent_networks.empty?

    unique_networks = recent_networks.uniq.size
    consistency = 1.0 - (unique_networks / 5.0)
    [consistency, 0.0].max
  end

  def check_time_zone_consistency(context)
    # Check if time zone is consistent with historical patterns
    current_tz = context[:time_zone]
    historical_tzs = @authentication.verification_history
      .where('created_at >= ?', 30.days.ago)
      .pluck(:time_zone)
      .compact
      .uniq

    historical_tzs.include?(current_tz)
  end

  def emulator_detected?(device_info)
    device_info[:emulator_score] > 0.8
  end

  def root_detected?(device_info)
    device_info[:root_score] > 0.7
  end

  def hook_detected?(device_info)
    device_info[:hook_score] > 0.6
  end

  def repackaged_app_detected?(device_info)
    device_info[:repackaging_score] > 0.7
  end

  def calculate_correlation_strength(score1, score2)
    # Calculate correlation strength between two pattern scores
    (score1 + score2) / 2.0
  end

  def load_behavioral_models
    # Load pre-trained behavioral analysis models
    model_configs = Rails.application.config.behavioral_models || []

    model_configs.map do |config|
      load_behavioral_model_from_config(config)
    end
  end

  def load_behavioral_model_from_config(config)
    # Load specific behavioral model based on configuration
    case config[:type]
    when :pattern_recognition
      PatternRecognitionModel.new(config)
    when :anomaly_detection
      AnomalyDetectionModel.new(config)
    when :risk_prediction
      RiskPredictionModel.new(config)
    else
      raise "Unknown behavioral model type: #{config[:type]}"
    end
  end

  def average_fingerprint(fingerprints)
    return nil if fingerprints.empty?
    # Simple average for demonstration
    fingerprints.first
  end

  def extract_device_behavior_from_info(device_info)
    # Extract behavioral data from device info
    device_info.slice(:orientation, :brightness, :volume, :connectivity)
  end

  def average_device_behavior(historical_device_data)
    # Calculate average device behavior from historical data
    behaviors = historical_device_data.map(&:behavior_data)
    return {} if behaviors.empty?

    # Simple averaging for demonstration
    behaviors.first
  end

  def calculate_behavioral_consistency(current, historical)
    # Calculate how consistent current behavior is with historical patterns
    return 0.5 if historical.empty?

    # Simple consistency calculation
    0.8 # Placeholder
  end
end

# Result classes
class BehavioralAnalysisResult
  attr_reader :anomaly_score, :confidence, :behavioral_patterns, :risk_factors, :profile_update, :recommendations

  def initialize(anomaly_score:, confidence:, behavioral_patterns:, risk_factors:, profile_update:, recommendations:)
    @anomaly_score = anomaly_score
    @confidence = confidence
    @behavioral_patterns = behavioral_patterns
    @risk_factors = risk_factors
    @profile_update = profile_update
    @recommendations = recommendations
  end

  def anomalous?
    @anomaly_score > 0.7
  end

  def to_h
    {
      anomaly_score: @anomaly_score,
      confidence: @confidence,
      behavioral_patterns: @behavioral_patterns,
      risk_factors: @risk_factors,
      profile_update: @profile_update,
      recommendations: @recommendations
    }
  end
end

class RiskAssessmentResult
  attr_reader :anomaly_score, :confidence, :risk_factors, :context

  def initialize(anomaly_score:, confidence:, risk_factors:, context:)
    @anomaly_score = anomaly_score
    @confidence = confidence
    @risk_factors = risk_factors
    @context = context
  end

  def high_risk?
    @anomaly_score > 0.8
  end

  def to_h
    {
      anomaly_score: @anomaly_score,
      confidence: @confidence,
      risk_factors: @risk_factors,
      context: @context
    }
  end
end

class DeviceIntegrityResult
  attr_reader :integrity_score, :confidence, :issues, :checks_performed

  def initialize(integrity_score:, confidence:, issues:, checks_performed:)
    @integrity_score = integrity_score
    @confidence = confidence
    @issues = issues
    @checks_performed = checks_performed
  end

  def compromised?
    @integrity_score < 0.5
  end

  def to_h
    {
      integrity_score: @integrity_score,
      confidence: @confidence,
      issues: @issues,
      checks_performed: @checks_performed
    }
  end
end

class DeviceIntegrityCheck
  attr_reader :type, :passed, :score, :details

  def initialize(type:, passed:, score:, details:)
    @type = type
    @passed = passed
    @score = score
    @details = details
  end
end