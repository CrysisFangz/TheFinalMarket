class AccessibilityFeedback < ApplicationRecord
  belongs_to :user, optional: true
  
  validates :page_url, presence: true
  validates :feedback_type, presence: true
  validates :description, presence: true
  
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
  
  # Scopes
  scope :open, -> { where(status: 'open') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :critical_issues, -> { where(severity: :critical) }
  scope :high_priority, -> { where(severity: [:high, :critical]) }
  
  # Create feedback from user
  def self.create_from_user(user, params)
    create!(
      user: user,
      page_url: params[:page_url],
      feedback_type: params[:feedback_type],
      description: params[:description],
      wcag_criterion: params[:wcag_criterion],
      severity: params[:severity] || :medium,
      assistive_technology: params[:assistive_technology],
      status: 'open'
    )
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
  
  # Get WCAG criterion distribution
  def self.wcag_distribution
    where.not(wcag_criterion: nil)
      .group(:wcag_criterion)
      .count
      .sort_by { |_, count| -count }
  end
end

