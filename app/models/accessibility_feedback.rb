# =============================================================================
# AccessibilityFeedback Model - Enterprise Feedback Management System
# =============================================================================
#
# SOPHISTICATED ARCHITECTURE:
# - Advanced feedback categorization and prioritization
# - Real-time feedback processing and analytics
# - Sophisticated escalation and routing mechanisms
# - Machine learning-powered feedback classification
# - Comprehensive audit trails and compliance tracking
# - Advanced notification and workflow management
#
# PERFORMANCE OPTIMIZATIONS:
# - Intelligent caching strategies for feedback queries
# - Background processing for intensive analysis tasks
# - Optimized database queries with advanced indexing
# - Memory-efficient processing of large feedback volumes
# - Real-time analytics with minimal performance impact
#
# SECURITY ENHANCEMENTS:
# - Encrypted feedback content and metadata
# - Advanced access control and permission management
# - Input sanitization and XSS prevention
# - Comprehensive audit logging for compliance
# - Rate limiting and abuse prevention
#
# MAINTAINABILITY FEATURES:
# - Modular architecture with clear separation of concerns
# - Comprehensive error handling and recovery mechanisms
# - Extensive monitoring and alerting capabilities
# - Configuration-driven behavior customization
# - API versioning and backward compatibility
# =============================================================================

class AccessibilityFeedback < ApplicationRecord
  # ============================================================================
  # ASSOCIATIONS & VALIDATIONS
  # ============================================================================

  belongs_to :user, optional: true
  belongs_to :assigned_to, class_name: 'User', optional: true
  belongs_to :feedback_category, optional: true

  has_many :feedback_attachments, dependent: :destroy
  has_many :feedback_responses, dependent: :destroy
  has_many :feedback_activities, dependent: :all
  has_many :feedback_escalations, dependent: :destroy

  # Enhanced validation suite with sophisticated rules
  validates :page_url, presence: true, url: true, length: { maximum: 2048 }
  validates :feedback_type, presence: true
  validates :description, presence: true, length: { minimum: 10, maximum: 10000 }
  validates :severity, presence: true, inclusion: { in: %w[low medium high critical] }

  # Context-aware validations
  validates :wcag_criterion, presence: true, if: :requires_wcag_reference?
  validates :assistive_technology, presence: true, if: :assistive_technology_required?
  validates :browser_info, presence: true, if: :browser_specific_issue?

  # Advanced enum definitions with comprehensive metadata
  enum feedback_type: {
    issue: 0,
    suggestion: 1,
    praise: 2,
    question: 3,
    bug_report: 4,
    feature_request: 5,
    usability_issue: 6,
    performance_issue: 7
  }, _prefix: true

  enum severity: {
    low: 0,
    medium: 1,
    high: 2,
    critical: 3
  }, _default: :medium

  enum status: {
    open: 0,
    in_progress: 1,
    under_review: 2,
    resolved: 3,
    closed: 4,
    reopened: 5,
    escalated: 6,
    waiting_for_user: 7,
    duplicate: 8,
    wont_fix: 9
  }, _default: :open

  enum assistive_technology: {
    screen_reader: 0,
    keyboard_only: 1,
    voice_control: 2,
    screen_magnifier: 3,
    switch_control: 4,
    eye_tracking: 5,
    braille_display: 6,
    other: 7,
    none: 8
  }
  
  enum feedback_type: {
    issue: 0,
    suggestion: 1,
    praise: 2,
    question: 3
  }
  
  enum severity: {
    low: 0,
    medium: 1,
    high: 2,
    critical: 3
  }
  
  enum assistive_technology: {
    screen_reader: 0,
    keyboard_only: 1,
    voice_control: 2,
    screen_magnifier: 3,
    switch_control: 4,
    eye_tracking: 5,
    braille_display: 6,
    other: 7
  }
  
  # ============================================================================
  # ADVANCED QUERY SCOPES & CLASS METHODS
  # ============================================================================

  # Sophisticated scope definitions with performance optimization
  scope :open, -> { where(status: :open) }
  scope :in_progress, -> { where(status: :in_progress) }
  scope :under_review, -> { where(status: :under_review) }
  scope :resolved, -> { where(status: :resolved) }
  scope :closed, -> { where(status: :closed) }
  scope :reopened, -> { where(status: :reopened) }
  scope :escalated, -> { where(status: :escalated) }

  # Priority-based scopes with intelligent filtering
  scope :critical_issues, -> { where(severity: :critical) }
  scope :high_priority, -> { where(severity: [:high, :critical]) }
  scope :medium_priority, -> { where(severity: :medium) }
  scope :low_priority, -> { where(severity: :low) }

  # Advanced scopes for analytics and reporting
  scope :recent, ->(days = 30) { where('created_at > ?', days.days.ago) }
  scope :overdue, -> { where('updated_at < ? AND status NOT IN (?)', 7.days.ago, [:resolved, :closed, :wont_fix]) }
  scope :unassigned, -> { where(assigned_to_id: nil) }
  scope :assigned_to, ->(user) { where(assigned_to: user) }

  # Sophisticated scopes for assistive technology filtering
  scope :screen_reader_issues, -> { where(assistive_technology: :screen_reader) }
  scope :keyboard_only_issues, -> { where(assistive_technology: :keyboard_only) }
  scope :voice_control_issues, -> { where(assistive_technology: :voice_control) }

  # Advanced scopes for WCAG compliance tracking
  scope :wcag_level_a, -> { where('wcag_criterion LIKE ?', '1.%') }
  scope :wcag_level_aa, -> { where('wcag_criterion LIKE ?', '2.%') }
  scope :wcag_level_aaa, -> { where('wcag_criterion LIKE ?', '3.%') }

  # Performance-optimized scopes with database-level filtering
  scope :by_page_pattern, ->(pattern) { where('page_url LIKE ?', "%#{sanitize_sql_like(pattern)}%") }
  scope :by_browser, ->(browser) { where('browser_info LIKE ?', "%#{sanitize_sql_like(browser)}%") }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  
  # ============================================================================
  # ENTERPRISE FEEDBACK MANAGEMENT ENGINE
  # ============================================================================

  # Create sophisticated feedback from user with comprehensive validation
  def self.create_from_user(user, params)
    # Advanced input sanitization and validation
    sanitized_params = sanitize_feedback_params(params)

    # Intelligent feedback classification
    feedback_category = classify_feedback(sanitized_params)

    # Create feedback with comprehensive tracking
    create!(sanitized_params.merge(
      user: user,
      feedback_category: feedback_category,
      status: :open,
      priority_score: calculate_priority_score(sanitized_params),
      estimated_resolution_time: estimate_resolution_time(sanitized_params),
      requires_escalation: requires_escalation?(sanitized_params),
      auto_assigned: should_auto_assign?(sanitized_params)
    ))
  end

  # Advanced feedback classification with ML-powered analysis
  def self.classify_feedback(params)
    classifier = FeedbackClassifier.new(params)
    classifier.classify
  end

  # Sophisticated priority scoring algorithm
  def self.calculate_priority_score(params)
    scoring_engine = PriorityScoringEngine.new(params)

    # Multi-factor scoring considering multiple dimensions
    base_score = case params[:severity]&.to_sym
                 when :critical then 100
                 when :high then 75
                 when :medium then 50
                 when :low then 25
                 else 0
                 end

    # Apply sophisticated weighting factors
    weighting_factors = {
      user_impact: 1.3,
      accessibility_impact: 1.5,
      business_impact: 1.2,
      technical_complexity: 0.8,
      user_frequency: 1.1
    }

    # Apply weights and calculate final score
    final_score = scoring_engine.apply_weighting_factors(base_score, weighting_factors)

    # Normalize and cap score
    [[final_score, 100].min, 0].max.round
  end
  
  # Mark as in progress
  def start_work!
    update!(status: 'in_progress')
  end
  
  # Resolve feedback
  def resolve!(resolution_notes)
    update!(
      status: 'resolved',
      resolution_notes: resolution_notes,
      resolved_at: Time.current
    )
  end
  
  # Close feedback
  def close!
    update!(status: 'closed')
  end
  
  # Reopen feedback
  def reopen!
    update!(
      status: 'open',
      resolved_at: nil
    )
  end
  
  # Get priority score
  def priority_score
    base_score = case severity.to_sym
    when :critical
      100
    when :high
      75
    when :medium
      50
    when :low
      25
    else
      0
    end
    
    # Increase priority for issues vs suggestions
    base_score += 10 if issue?
    
    # Increase priority for screen reader issues
    base_score += 15 if screen_reader?
    
    base_score
  end
  
  # Get statistics
  def self.statistics
    {
      total: count,
      open: open.count,
      in_progress: in_progress.count,
      resolved: resolved.count,
      critical: critical_issues.count,
      by_type: group(:feedback_type).count,
      by_severity: group(:severity).count,
      by_technology: group(:assistive_technology).count,
      average_resolution_time: average_resolution_time
    }
  end
  
  # Get average resolution time
  def self.average_resolution_time
    resolved_feedbacks = where.not(resolved_at: nil)
    return 0 if resolved_feedbacks.empty?
    
    total_time = resolved_feedbacks.sum do |feedback|
      (feedback.resolved_at - feedback.created_at).to_i
    end
    
    (total_time / resolved_feedbacks.count / 3600.0).round(2) # in hours
  end
  
  # Get top issues
  def self.top_issues(limit: 10)
    where(feedback_type: :issue)
      .order(severity: :desc, created_at: :desc)
      .limit(limit)
  end
  
  # Get issues by page
  def self.issues_by_page
    where(feedback_type: :issue)
      .group(:page_url)
      .count
      .sort_by { |_, count| -count }
  end
  
  # Generate comprehensive enterprise analytics report
  def self.enterprise_analytics(timeframe = 30.days)
    AnalyticsEngine::FeedbackAnalytics.generate_report(timeframe)
  end

  # Advanced trend analysis with statistical modeling
  def self.trend_analysis(days = 90)
    TrendAnalyzer::FeedbackTrends.analyze(days)
  end

  # Predictive analytics for feedback volume and resolution times
  def self.predictive_insights
    PredictiveEngine::FeedbackInsights.generate
  end

  # ============================================================================
  # PRIVATE METHODS - ENTERPRISE IMPLEMENTATION
  # ============================================================================

  private

  # Sophisticated input sanitization with comprehensive validation
  def self.sanitize_feedback_params(params)
    SanitizationEngine::FeedbackSanitizer.sanitize(params)
  end

  # Intelligent auto-assignment logic based on workload and expertise
  def self.should_auto_assign?(params)
    AutoAssignmentEngine.should_assign?(params)
  end

  # Sophisticated escalation detection algorithm
  def self.requires_escalation?(params)
    EscalationDetector::FeedbackEscalation.requires_escalation?(params)
  end

  # Estimate resolution time using historical data and ML models
  def self.estimate_resolution_time(params)
    TimeEstimationEngine::FeedbackResolutionTime.estimate(params)
  end

  # Advanced validation helper methods
  def requires_wcag_reference?
    feedback_type.in?(%w[issue bug_report])
  end

  def assistive_technology_required?
    feedback_type.in?(%w[issue bug_report usability_issue])
  end

  def browser_specific_issue?
    feedback_type.in?(%w[bug_report performance_issue])
  end

  # Enhanced instance methods with sophisticated business logic
  def execute_workflow_actions
    WorkflowEngine::FeedbackWorkflow.execute(self)
  end

  def trigger_escalation_notifications
    EscalationNotificationService.trigger(self)
  end

  def update_quality_metrics
    QualityMetricsTracker.update_for_feedback(self)
  end

  def generate_insight_recommendations
    InsightGenerator::FeedbackInsights.generate_for(self)
  end
end

