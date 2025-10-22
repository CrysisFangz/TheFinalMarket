# frozen_string_literal: true

# Hexagonal Architecture - Domain Layer
# Pure business model with no external dependencies
class BehavioralPattern < ApplicationRecord
  # Domain dependencies only - no infrastructure concerns
  belongs_to :user

  # Domain validations - pure business rules
  validates :pattern_type, presence: true, inclusion: { in: PATTERN_TYPES.keys }
  validates :detected_at, presence: true
  validates :pattern_data, presence: true

  # Domain constants - business vocabulary
  PATTERN_TYPES = {
    login_pattern: 0,
    browsing_pattern: 1,
    purchase_pattern: 2,
    messaging_pattern: 3,
    listing_pattern: 4,
    search_pattern: 5,
    velocity_pattern: 6,
    time_pattern: 7,
    location_pattern: 8,
    device_pattern: 9
  }.freeze

  # Domain enums - business concepts
  enum pattern_type: PATTERN_TYPES, _prefix: true

  # Query scopes - domain-specific queries
  scope :recent, -> { where('detected_at > ?', 30.days.ago) }
  scope :anomalous, -> { where(anomalous: true) }
  scope :for_user, ->(user) { where(user: user) }
  scope :by_pattern_type, ->(type) { where(pattern_type: type) }

  # Domain events for event sourcing capabilities
  after_commit :publish_domain_events, on: [:create, :update]

  # ==================== DOMAIN BEHAVIOR ====================

  # Pure domain logic - anomaly assessment
  def anomalous?
    anomalous == true
  end

  # Domain business rule - anomaly classification
  def anomaly_severity
    return :none unless anomalous?

    score = anomaly_score
    case score
    when 0..30 then :low
    when 31..60 then :medium
    when 61..85 then :high
    else :critical
    end
  end

  # Domain business rule - pattern confidence assessment
  def confidence_level
    base_confidence = pattern_data['sample_size'].to_i / 100.0
    base_confidence *= pattern_data['statistical_significance'].to_f
    [base_confidence, 1.0].min
  end

  # Domain business rule - pattern staleness
  def stale?
    detected_at < 24.hours.ago
  end

  # ==================== APPLICATION SERVICES ====================

  # Orchestration method - delegates to application services
  def self.detect_anomalies_for(user)
    result = BehavioralAnalysisService.call(user)
    result.success? ? result.patterns : []
  end

  # ==================== PRESENTATION LOGIC ====================

  # Presentation logic - delegates to presenters
  def description
    @description ||= PatternDescriptionPresenter.present(self)
  end

  def summary
    @summary ||= PatternSummaryPresenter.present(self)
  end

  # ==================== PRIVATE DOMAIN METHODS ====================

  private

  # Domain event publishing for event sourcing
  def publish_domain_events
    return unless saved_changes?

    event = BehavioralPatternDetectedEvent.new(
      pattern_id: id,
      user_id: user_id,
      pattern_type: pattern_type,
      anomalous: anomalous,
      detected_at: detected_at,
      changes: saved_changes
    )

    EventPublisher.publish(event)
  end

  # Enhanced anomaly scoring with sophisticated algorithms
  def anomaly_score
    return 0 unless anomalous?

    calculator = AnomalyScoreCalculator.new(pattern_data)
    calculator.calculate
  end
end

# ==================== DOMAIN VALUE OBJECTS ====================

# Immutable value objects for domain concepts
BehavioralPattern::AnomalyScore = Struct.new(:value, :confidence, :factors) do
  def initialize(value, confidence = 1.0, factors = [])
    super(value, confidence, factors)
    freeze # Immutable value object
  end

  def severity
    case value
    when 0..30 then :low
    when 31..60 then :medium
    when 61..85 then :high
    else :critical
    end
  end

  def high_risk?
    value >= 70
  end

  def to_h
    { value: value, confidence: confidence, factors: factors, severity: severity }
  end
end

# Pattern metadata value object
BehavioralPattern::PatternMetadata = Struct.new(
  :sample_size, :time_window, :algorithm_version, :statistical_significance
) do
  def initialize(sample_size, time_window, algorithm_version, statistical_significance = 0.95)
    super(sample_size, time_window, algorithm_version, statistical_significance)
    freeze
  end

  def reliable?
    sample_size >= 50 && statistical_significance >= 0.95
  end

  def to_h
    {
      sample_size: sample_size,
      time_window: time_window,
      algorithm_version: algorithm_version,
      statistical_significance: statistical_significance,
      reliable: reliable?
    }
  end
end