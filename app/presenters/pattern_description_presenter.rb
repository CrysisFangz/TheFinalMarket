# frozen_string_literal: true

# Pattern Description Presenter - Hexagonal Architecture Presentation Layer
# Decouples business logic from presentation concerns
# Implements sophisticated formatting and internationalization
class PatternDescriptionPresenter
  # Internationalization support for multiple languages
  I18N_KEYS = {
    login_pattern: 'behavioral_patterns.login',
    browsing_pattern: 'behavioral_patterns.browsing',
    purchase_pattern: 'behavioral_patterns.purchase',
    messaging_pattern: 'behavioral_patterns.messaging',
    listing_pattern: 'behavioral_patterns.listing',
    search_pattern: 'behavioral_patterns.search',
    velocity_pattern: 'behavioral_patterns.velocity',
    time_pattern: 'behavioral_patterns.time',
    location_pattern: 'behavioral_patterns.location',
    device_pattern: 'behavioral_patterns.device'
  }.freeze

  # Risk level formatting and styling
  RISK_STYLES = {
    low: { class: 'risk-low', icon: '🟢', priority: 1 },
    medium: { class: 'risk-medium', icon: '🟡', priority: 2 },
    high: { class: 'risk-high', icon: '🟠', priority: 3 },
    critical: { class: 'risk-critical', icon: '🔴', priority: 4 }
  }.freeze

  def self.present(pattern)
    new(pattern).present
  end

  def initialize(pattern)
    @pattern = pattern
    @pattern_data = pattern.pattern_data || {}
    freeze # Immutable presenter instance
  end

  def present
    {
      formatted_description: generate_formatted_description,
      technical_details: generate_technical_details,
      user_friendly_summary: generate_user_friendly_summary,
      risk_assessment: generate_risk_assessment,
      actionable_insights: generate_actionable_insights,
      presentation_metadata: generate_presentation_metadata
    }
  end

  private

  def generate_formatted_description
    case @pattern.pattern_type.to_sym
    when :login_pattern
      format_login_description
    when :browsing_pattern
      format_browsing_description
    when :purchase_pattern
      format_purchase_description
    when :messaging_pattern
      format_messaging_description
    when :listing_pattern
      format_listing_description
    when :velocity_pattern
      format_velocity_description
    when :time_pattern
      format_time_description
    when :location_pattern
      format_location_description
    when :device_pattern
      format_device_description
    else
      format_generic_description
    end
  end

  def format_login_description
    description = @pattern_data['description'] || 'Login behavior detected'

    # Enhanced login pattern description with context
    if @pattern_data['login_context']
      context = @pattern_data['login_context']
      device_info = context['device_info'] ? " from #{context['device_info']}" : ''
      location_info = context['location_info'] ? " in #{context['location_info']}" : ''

      "Login Pattern: #{description}#{device_info}#{location_info} at #{formatted_timestamp}"
    else
      "Login Pattern: #{description}"
    end
  end

  def format_browsing_description
    description = @pattern_data['description'] || 'Browsing behavior detected'

    if @pattern_data['browsing_metrics']
      metrics = @pattern_data['browsing_metrics']
      page_views = metrics['page_views'] || 0
      session_duration = format_duration(metrics['session_duration'])

      "Browsing Pattern: #{description} (#{page_views} pages, #{session_duration})"
    else
      "Browsing Pattern: #{description}"
    end
  end

  def format_purchase_description
    description = @pattern_data['description'] || 'Purchase behavior detected'

    if @pattern_data['purchase_context']
      context = @pattern_data['purchase_context']
      order_count = context['order_count'] || 0
      total_value = format_currency(context['total_value'])

      "Purchase Pattern: #{description} (#{order_count} orders, #{total_value})"
    else
      "Purchase Pattern: #{description}"
    end
  end

  def format_messaging_description
    description = @pattern_data['description'] || 'Messaging behavior detected'

    if @pattern_data['messaging_metrics']
      metrics = @pattern_data['messaging_metrics']
      message_count = metrics['message_count'] || 0
      conversation_count = metrics['conversation_count'] || 0

      "Messaging Pattern: #{description} (#{message_count} messages, #{conversation_count} conversations)"
    else
      "Messaging Pattern: #{description}"
    end
  end

  def format_listing_description
    description = @pattern_data['description'] || 'Listing behavior detected'

    if @pattern_data['listing_metrics']
      metrics = @pattern_data['listing_metrics']
      listing_count = metrics['listing_count'] || 0
      category_focus = metrics['primary_category']

      category_text = category_focus ? " focused on #{category_focus}" : ''
      "Listing Pattern: #{description} (#{listing_count} listings#{category_text})"
    else
      "Listing Pattern: #{description}"
    end
  end

  def format_velocity_description
    description = @pattern_data['description'] || 'Activity velocity detected'

    if @pattern_data['velocity_metrics']
      metrics = @pattern_data['velocity_metrics']
      current_rate = metrics['current_rate'] || 0
      baseline_rate = metrics['baseline_rate'] || 1
      rate_ratio = (current_rate.to_f / baseline_rate * 100).round(1)

      "Velocity Pattern: #{description} (#{rate_ratio}% of baseline activity rate)"
    else
      "Velocity Pattern: #{description}"
    end
  end

  def format_time_description
    description = @pattern_data['description'] || 'Time pattern detected'

    if @pattern_data['time_context']
      context = @pattern_data['time_context']
      unusual_hour = context['unusual_hour']
      historical_pattern = context['historical_pattern']

      hour_context = unusual_hour ? " at unusual hour #{unusual_hour}:00" : ''
      pattern_context = historical_pattern ? " vs historical #{historical_pattern}" : ''

      "Time Pattern: #{description}#{hour_context}#{pattern_context}"
    else
      "Time Pattern: #{description}"
    end
  end

  def format_location_description
    description = @pattern_data['description'] || 'Location pattern detected'

    if @pattern_data['location_context']
      context = @pattern_data['location_context']
      location_info = context['location_info']
      travel_info = context['travel_info']

      location_text = location_info ? " from #{location_info}" : ''
      travel_text = travel_info ? " (#{travel_info})" : ''

      "Location Pattern: #{description}#{location_text}#{travel_text}"
    else
      "Location Pattern: #{description}"
    end
  end

  def format_device_description
    description = @pattern_data['description'] || 'Device pattern detected'

    if @pattern_data['device_context']
      context = @pattern_data['device_context']
      device_info = context['device_info']
      fingerprint_info = context['fingerprint_info']

      device_text = device_info ? " using #{device_info}" : ''
      fingerprint_text = fingerprint_info ? " (fingerprint: #{fingerprint_info})" : ''

      "Device Pattern: #{description}#{device_text}#{fingerprint_text}"
    else
      "Device Pattern: #{description}"
    end
  end

  def format_generic_description
    description = @pattern_data['description'] || 'Behavioral pattern detected'

    # Add pattern metadata for context
    metadata = []
    metadata << "Type: #{@pattern.pattern_type}" if @pattern.pattern_type
    metadata << "Confidence: #{(@pattern.confidence_level * 100).round(1)}%" if @pattern.confidence_level
    metadata << "Detected: #{formatted_timestamp}"

    base_description = description
    base_description += " (#{metadata.join(', ')})" if metadata.any?

    base_description
  end

  def generate_technical_details
    {
      pattern_type: @pattern.pattern_type,
      pattern_type_label: humanize_pattern_type(@pattern.pattern_type),
      anomaly_score: @pattern.anomaly_score,
      confidence_level: @pattern.confidence_level,
      anomaly_severity: @pattern.anomaly_severity,
      detected_at: @pattern.detected_at,
      time_since_detection: format_time_since_detection,
      pattern_metadata: extract_pattern_metadata,
      statistical_measures: extract_statistical_measures
    }
  end

  def generate_user_friendly_summary
    {
      title: generate_summary_title,
      description: generate_summary_description,
      impact_assessment: assess_impact,
      recommended_actions: suggest_actions,
      related_patterns: find_related_patterns
    }
  end

  def generate_risk_assessment
    severity = @pattern.anomaly_severity
    risk_style = RISK_STYLES[severity] || RISK_STYLES[:low]

    {
      severity: severity,
      risk_level: map_severity_to_risk_level(severity),
      visual_indicator: risk_style[:icon],
      styling_class: risk_style[:class],
      priority_score: risk_style[:priority],
      risk_factors: extract_risk_factors,
      mitigation_suggestions: generate_mitigation_suggestions(severity)
    }
  end

  def generate_actionable_insights
    insights = []

    # Pattern-specific insights
    case @pattern.pattern_type.to_sym
    when :login_pattern
      insights.concat(generate_login_insights)
    when :purchase_pattern
      insights.concat(generate_purchase_insights)
    when :velocity_pattern
      insights.concat(generate_velocity_insights)
    when :location_pattern
      insights.concat(generate_location_insights)
    end

    # General insights based on anomaly severity
    insights.concat(generate_severity_based_insights)

    insights.uniq { |insight| insight[:type] }
  end

  def generate_presentation_metadata
    {
      presenter_version: '2.0.0',
      generation_timestamp: Time.current,
      localization: I18n.locale,
      formatting_preferences: extract_formatting_preferences,
      accessibility_features: generate_accessibility_features
    }
  end

  # Helper methods for formatting and content generation

  def formatted_timestamp
    @pattern.detected_at.strftime('%Y-%m-%d %H:%M:%S UTC')
  end

  def format_time_since_detection
    time_diff = Time.current - @pattern.detected_at

    if time_diff < 1.hour
      "#{time_diff.to_i} minutes ago"
    elsif time_diff < 24.hours
      "#{(time_diff / 3600).round} hours ago"
    else
      "#{(time_diff / 86400).round} days ago"
    end
  end

  def format_duration(seconds)
    return 'unknown' unless seconds

    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      "#{(seconds / 60).round}m"
    else
      "#{(seconds / 3600).round}h"
    end
  end

  def format_currency(amount_cents)
    return '$0.00' unless amount_cents

    amount_dollars = amount_cents / 100.0
    format('$%.2f', amount_dollars)
  end

  def humanize_pattern_type(pattern_type)
    pattern_type.to_s.humanize.titleize
  end

  def extract_pattern_metadata
    @pattern_data.slice('algorithm_version', 'sample_size', 'statistical_significance')
  end

  def extract_statistical_measures
    @pattern_data.slice('mean', 'std_dev', 'confidence_interval', 'p_value')
  end

  def generate_summary_title
    severity = @pattern.anomaly_severity
    pattern_name = humanize_pattern_type(@pattern.pattern_type)

    case severity
    when :critical then "Critical: #{pattern_name} Anomaly"
    when :high then "High Risk: #{pattern_name} Pattern"
    when :medium then "Moderate: #{pattern_name} Behavior"
    else "Normal: #{pattern_name} Activity"
    end
  end

  def generate_summary_description
    case @pattern.anomaly_severity
    when :critical
      "Critical behavioral anomaly detected requiring immediate attention."
    when :high
      "High-risk behavioral pattern identified for review."
    when :medium
      "Moderate behavioral pattern detected for monitoring."
    else
      "Normal behavioral pattern within expected parameters."
    end
  end

  def assess_impact
    case @pattern.pattern_type.to_sym
    when :login_pattern then assess_login_impact
    when :purchase_pattern then assess_purchase_impact
    when :velocity_pattern then assess_velocity_impact
    else assess_generic_impact
    end
  end

  def assess_login_impact
    if @pattern_data['login_context']&.dig('rapid_logins')
      { level: :high, description: 'Multiple rapid login attempts detected' }
    else
      { level: :medium, description: 'Unusual login pattern identified' }
    end
  end

  def assess_purchase_impact
    if @pattern_data['purchase_context']&.dig('high_value_orders')
      { level: :high, description: 'High-value purchase pattern detected' }
    else
      { level: :medium, description: 'Unusual purchase behavior identified' }
    end
  end

  def assess_velocity_impact
    velocity_ratio = @pattern_data['velocity_metrics']&.dig('velocity_ratio') || 1.0

    case velocity_ratio
    when 5.0..Float::INFINITY then { level: :critical, description: 'Extreme activity burst detected' }
    when 3.0..5.0 then { level: :high, description: 'High activity spike identified' }
    else { level: :medium, description: 'Elevated activity level detected' }
    end
  end

  def assess_generic_impact
    case @pattern.anomaly_severity
    when :critical then { level: :critical, description: 'Critical anomaly requiring immediate action' }
    when :high then { level: :high, description: 'High-priority pattern for review' }
    else { level: :medium, description: 'Pattern detected for monitoring' }
    end
  end

  def suggest_actions
    actions = []

    case @pattern.anomaly_severity
    when :critical
      actions << :immediate_review << :security_notification << :account_verification
    when :high
      actions << :detailed_review << :enhanced_monitoring
    when :medium
      actions << :standard_monitoring
    end

    # Pattern-specific actions
    case @pattern.pattern_type.to_sym
    when :login_pattern
      actions << :login_verification << :device_tracking
    when :purchase_pattern
      actions << :transaction_review << :payment_verification
    when :location_pattern
      actions << :location_verification << :travel_analysis
    end

    actions.uniq
  end

  def find_related_patterns
    # Find other patterns for the same user within time window
    time_window = 24.hours.ago..Time.current

    related_patterns = @pattern.class.where(user: @pattern.user)
                              .where(detected_at: time_window)
                              .where.not(id: @pattern.id)
                              .limit(5)

    related_patterns.map do |related_pattern|
      {
        id: related_pattern.id,
        pattern_type: related_pattern.pattern_type,
        severity: related_pattern.anomaly_severity,
        detected_at: related_pattern.detected_at,
        relevance_score: calculate_pattern_relevance(@pattern, related_pattern)
      }
    end.sort_by { |p| -p[:relevance_score] }
  end

  def calculate_pattern_relevance(pattern1, pattern2)
    # Calculate relevance between patterns for correlation analysis
    score = 0.0

    # Same pattern type gets higher relevance
    score += 0.4 if pattern1.pattern_type == pattern2.pattern_type

    # Temporal proximity increases relevance
    time_diff = (pattern1.detected_at - pattern2.detected_at).abs
    temporal_score = [1.0 - (time_diff / 3600), 0.0].max # 1 hour window
    score += temporal_score * 0.3

    # Same severity level increases relevance
    score += 0.3 if pattern1.anomaly_severity == pattern2.anomaly_severity

    score
  end

  def extract_risk_factors
    risk_factors = []

    # Extract risk factors from pattern data
    if @pattern_data['risk_factors']
      risk_factors.concat(@pattern_data['risk_factors'])
    end

    # Pattern-specific risk factors
    case @pattern.pattern_type.to_sym
    when :login_pattern
      risk_factors << 'Authentication anomaly' if @pattern.anomalous?
    when :purchase_pattern
      risk_factors << 'Transaction anomaly' if @pattern.anomalous?
    when :velocity_pattern
      risk_factors << 'Activity burst' if @pattern.anomalous?
    end

    risk_factors.uniq
  end

  def generate_mitigation_suggestions(severity)
    suggestions = []

    case severity
    when :critical
      suggestions << 'Immediate manual review required' << 'Consider account suspension' << 'Notify security team'
    when :high
      suggestions << 'Detailed investigation recommended' << 'Enhanced monitoring' << 'Additional verification'
    when :medium
      suggestions << 'Standard monitoring procedures' << 'Periodic review' << 'Baseline establishment'
    else
      suggestions << 'No action required' << 'Continue normal monitoring'
    end

    suggestions
  end

  def generate_login_insights
    insights = []

    if @pattern_data['login_context']&.dig('unusual_timing')
      insights << {
        type: :timing_anomaly,
        message: 'Login occurred at unusual time for this user',
        confidence: 0.8,
        recommendation: 'Verify user identity and device authenticity'
      }
    end

    if @pattern_data['login_context']&.dig('rapid_logins')
      insights << {
        type: :rapid_attempts,
        message: 'Multiple rapid login attempts detected',
        confidence: 0.9,
        recommendation: 'Review for potential brute force attack'
      }
    end

    insights
  end

  def generate_purchase_insights
    insights = []

    if @pattern_data['purchase_context']&.dig('unusual_value')
      insights << {
        type: :value_anomaly,
        message: 'Purchase value significantly different from normal',
        confidence: 0.75,
        recommendation: 'Verify transaction legitimacy and payment method'
      }
    end

    if @pattern_data['purchase_context']&.dig('rapid_purchases')
      insights << {
        type: :frequency_anomaly,
        message: 'Unusual purchase frequency detected',
        confidence: 0.8,
        recommendation: 'Review for potential account compromise'
      }
    end

    insights
  end

  def generate_velocity_insights
    insights = []

    velocity_ratio = @pattern_data['velocity_metrics']&.dig('velocity_ratio') || 1.0

    if velocity_ratio > 5.0
      insights << {
        type: :extreme_burst,
        message: 'Extreme activity burst detected',
        confidence: 0.85,
        recommendation: 'Investigate for potential automated behavior or account compromise'
      }
    elsif velocity_ratio > 3.0
      insights << {
        type: :high_activity,
        message: 'Elevated activity level identified',
        confidence: 0.7,
        recommendation: 'Monitor for sustained unusual activity'
      }
    end

    insights
  end

  def generate_location_insights
    insights = []

    if @pattern_data['location_context']&.dig('impossible_travel')
      insights << {
        type: :impossible_travel,
        message: 'Geographically impossible travel pattern detected',
        confidence: 0.95,
        recommendation: 'Immediate verification required - potential account compromise'
      }
    elsif @pattern_data['location_context']&.dig('new_location')
      insights << {
        type: :new_location,
        message: 'Activity from new geographic location',
        confidence: 0.6,
        recommendation: 'Verify location legitimacy and user consent'
      }
    end

    insights
  end

  def generate_severity_based_insights
    insights = []

    case @pattern.anomaly_severity
    when :critical
      insights << {
        type: :critical_risk,
        message: 'Critical anomaly requires immediate attention',
        confidence: 0.95,
        recommendation: 'Escalate to security team immediately'
      }
    when :high
      insights << {
        type: :high_risk,
        message: 'High-risk pattern detected',
        confidence: 0.8,
        recommendation: 'Schedule detailed review within 24 hours'
      }
    end

    insights
  end

  def map_severity_to_risk_level(severity)
    case severity
    when :critical then :critical
    when :high then :high
    when :medium then :moderate
    else :low
    end
  end

  def extract_formatting_preferences
    {
      timestamp_format: '%Y-%m-%d %H:%M:%S UTC',
      currency_locale: I18n.locale,
      number_precision: 2,
      use_icons: true,
      compact_mode: false
    }
  end

  def generate_accessibility_features
    {
      screen_reader_compatible: true,
      high_contrast_support: true,
      keyboard_navigation: true,
      aria_labels: generate_aria_labels,
      semantic_structure: true
    }
  end

  def generate_aria_labels
    severity = @pattern.anomaly_severity

    {
      pattern_description: "#{humanize_pattern_type(@pattern.pattern_type)} behavioral pattern",
      risk_level: "Risk level: #{severity}",
      detection_time: "Detected at #{formatted_timestamp}",
      confidence_score: "Confidence level: #{(@pattern.confidence_level * 100).round(1)} percent"
    }
  end
end