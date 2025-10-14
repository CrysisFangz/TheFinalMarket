# frozen_string_literal: true

module Admin
  # Sophisticated presenter for seller application data with enhanced display logic
  class SellerApplicationPresenter
    include ActionView::Helpers::DateHelper
    include ActionView::Helpers::NumberHelper

    attr_reader :seller_application, :view_context

    # Initializes the presenter with the seller application and view context
    # @param seller_application [SellerApplication] The application to present
    # @param view_context [ActionView::Base] Rails view context for helpers
    def initialize(seller_application, view_context = nil)
      @seller_application = seller_application
      @view_context = view_context
    end

    # Presents the seller application with all enhanced display data
    # @return [Hash] Complete presentation data
    def present
      {
        id: seller_application.id,
        status: presented_status,
        user: presented_user,
        application_details: presented_application_details,
        metrics: presented_metrics,
        timeline: presented_timeline,
        actions: presented_actions,
        alerts: presented_alerts,
        metadata: presented_metadata
      }
    end

    # Returns formatted status with appropriate styling classes
    # @return [Hash] Status information with styling
    def presented_status
      status_config = {
        'pending' => { label: 'Pending Review', css_class: 'badge-warning', icon: 'clock' },
        'under_review' => { label: 'Under Review', css_class: 'badge-info', icon: 'search' },
        'approved' => { label: 'Approved', css_class: 'badge-success', icon: 'check-circle' },
        'rejected' => { label: 'Rejected', css_class: 'badge-danger', icon: 'x-circle' },
        'suspended' => { label: 'Suspended', css_class: 'badge-secondary', icon: 'pause-circle' }
      }

      config = status_config[seller_application.status.to_s] || status_config['pending']
      {
        value: seller_application.status,
        label: config[:label],
        css_class: config[:css_class],
        icon: config[:icon],
        badge_html: badge_html(config[:label], config[:css_class])
      }
    end

    # Returns comprehensive user information
    # @return [Hash] User presentation data
    def presented_user
      user = seller_application.user
      return {} unless user

      {
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        avatar_url: user.avatar_url || default_avatar_url,
        join_date: format_date(user.created_at),
        reputation_score: user.reputation_score,
        total_orders: user.orders_count,
        account_status: user.account_status,
        verification_level: user.verification_level,
        risk_score: calculate_risk_score(user),
        profile_completeness: calculate_profile_completeness(user)
      }
    end

    # Returns detailed application information
    # @return [Hash] Application details
    def presented_application_details
      {
        submitted_at: format_date(seller_application.created_at),
        reviewed_at: format_date(seller_application.updated_at),
        processing_time: calculate_processing_time,
        feedback: seller_application.feedback,
        admin_notes: seller_application.admin_notes,
        documents: presented_documents,
        verification_status: verification_status,
        compliance_score: calculate_compliance_score
      }
    end

    # Returns key metrics for the application
    # @return [Hash] Metrics data
    def presented_metrics
      {
        days_pending: calculate_days_pending,
        review_priority: calculate_priority_score,
        completion_percentage: calculate_completion_percentage,
        risk_indicators: risk_indicators,
        trust_signals: trust_signals
      }
    end

    # Returns timeline of application events
    # @return [Array] Timeline events
    def presented_timeline
      events = []

      # Application submitted
      events << {
        timestamp: seller_application.created_at,
        event: 'Application Submitted',
        description: 'Seller application was submitted for review',
        icon: 'file-text',
        css_class: 'timeline-info'
      }

      # Status changes
      if seller_application.updated_at != seller_application.created_at
        events << {
          timestamp: seller_application.updated_at,
          event: 'Status Updated',
          description: "Application status changed to #{seller_application.status.titleize}",
          icon: 'edit',
          css_class: 'timeline-warning'
        }
      end

      # Add admin action logs if available
      admin_logs = fetch_admin_logs
      events.concat(admin_logs)

      events.sort_by! { |event| event[:timestamp] }
    end

    # Returns available actions for the current application state
    # @return [Array] Available actions
    def presented_actions
      actions = []

      case seller_application.status.to_s
      when 'pending'
        actions << { name: 'approve', label: 'Approve Application', css_class: 'btn-success', icon: 'check' }
        actions << { name: 'reject', label: 'Reject Application', css_class: 'btn-danger', icon: 'x' }
        actions << { name: 'request_more_info', label: 'Request More Information', css_class: 'btn-info', icon: 'help-circle' }
      when 'under_review'
        actions << { name: 'approve', label: 'Approve Application', css_class: 'btn-success', icon: 'check' }
        actions << { name: 'reject', label: 'Reject Application', css_class: 'btn-danger', icon: 'x' }
      when 'approved'
        actions << { name: 'suspend', label: 'Suspend Seller', css_class: 'btn-warning', icon: 'pause' }
      when 'suspended'
        actions << { name: 'reactivate', label: 'Reactivate Seller', css_class: 'btn-success', icon: 'play' }
        actions << { name: 'reject', label: 'Reject Application', css_class: 'btn-danger', icon: 'x' }
      end

      actions
    end

    # Returns important alerts or warnings
    # @return [Array] Alert messages
    def presented_alerts
      alerts = []

      # High-risk application alert
      if high_risk_application?
        alerts << {
          type: 'warning',
          message: 'This application has been flagged as high risk',
          icon: 'alert-triangle'
        }
      end

      # Long-pending application alert
      if long_pending_application?
        alerts << {
          type: 'info',
          message: 'This application has been pending for an extended period',
          icon: 'clock'
        }
      end

      # Incomplete documentation alert
      if incomplete_documentation?
        alerts << {
          type: 'error',
          message: 'Required documentation is missing',
          icon: 'file-x'
        }
      end

      alerts
    end

    # Returns metadata for the application
    # @return [Hash] Metadata
    def presented_metadata
      {
        cache_timestamp: Time.current,
        presenter_version: '2.0',
        data_freshness: calculate_data_freshness,
        export_formats: ['json', 'csv', 'pdf']
      }
    end

    private

    # Generates HTML badge for status
    def badge_html(label, css_class)
      return '' unless view_context

      view_context.content_tag(:span, label, class: "badge #{css_class}")
    end

    # Formats date for display
    def format_date(date)
      return '' unless date

      if view_context
        view_context.content_tag(:span, time_ago_in_words(date), title: date.strftime('%B %d, %Y at %I:%M %p'))
      else
        time_ago_in_words(date)
      end
    end

    # Returns default avatar URL
    def default_avatar_url
      'https://via.placeholder.com/40x40?text=User'
    end

    # Calculates processing time in business days
    def calculate_processing_time
      return 0 unless seller_application.updated_at && seller_application.created_at

      business_days_between(seller_application.created_at, seller_application.updated_at)
    end

    # Calculates days pending for current pending applications
    def calculate_days_pending
      return 0 if seller_application.status != 'pending'

      (Time.current.to_date - seller_application.created_at.to_date).to_i
    end

    # Calculates priority score based on various factors
    def calculate_priority_score
      score = 0
      score += 10 if high_risk_application?
      score += 5 if long_pending_application?
      score += 3 if seller_application.user&.high_value_potential?
      score
    end

    # Calculates completion percentage
    def calculate_completion_percentage
      total_fields = 10 # Total number of fields to check
      completed_fields = 0

      completed_fields += 1 if seller_application.user&.first_name.present?
      completed_fields += 1 if seller_application.user&.last_name.present?
      completed_fields += 1 if seller_application.user&.email.present?
      completed_fields += 1 if seller_application.feedback.present?
      completed_fields += 1 if seller_application.admin_notes.present?
      # Add more field checks as needed

      (completed_fields.to_f / total_fields * 100).round
    end

    # Returns risk indicators
    def risk_indicators
      indicators = []

      if seller_application.user&.high_risk_score?
        indicators << { type: 'high_risk_score', severity: 'high', message: 'User has high risk score' }
      end

      if seller_application.user&.recent_warnings?
        indicators << { type: 'recent_warnings', severity: 'medium', message: 'User has recent warnings' }
      end

      indicators
    end

    # Returns trust signals
    def trust_signals
      signals = []

      if seller_application.user&.verified_email?
        signals << { type: 'verified_email', strength: 'high', message: 'Email is verified' }
      end

      if seller_application.user&.good_reputation?
        signals << { type: 'good_reputation', strength: 'high', message: 'Good reputation score' }
      end

      signals
    end

    # Checks if application is high risk
    def high_risk_application?
      seller_application.user&.high_risk_score? || risk_indicators.any? { |r| r[:severity] == 'high' }
    end

    # Checks if application has been pending too long
    def long_pending_application?
      calculate_days_pending > 7
    end

    # Checks if documentation is incomplete
    def incomplete_documentation?
      # Add logic to check for required documents
      false
    end

    # Fetches admin action logs for timeline
    def fetch_admin_logs
      # This would typically fetch from AdminActionLog model
      []
    end

    # Calculates business days between two dates
    def business_days_between(start_date, end_date)
      # Simple implementation - could be enhanced with business day logic
      (end_date.to_date - start_date.to_date).to_i
    end

    # Calculates data freshness score
    def calculate_data_freshness
      return 'fresh' if seller_application.updated_at > 1.hour.ago
      return 'recent' if seller_application.updated_at > 1.day.ago
      return 'stale' if seller_application.updated_at > 1.week.ago
      'outdated'
    end

    # Calculates user risk score
    def calculate_risk_score(user)
      # Implement risk calculation logic
      0
    end

    # Calculates profile completeness percentage
    def calculate_profile_completeness(user)
      # Implement profile completeness calculation
      0
    end

    # Returns verification status
    def verification_status
      {
        email_verified: seller_application.user&.verified_email?,
        identity_verified: seller_application.user&.identity_verified?,
        address_verified: seller_application.user&.address_verified?
      }
    end

    # Calculates compliance score
    def calculate_compliance_score
      # Implement compliance scoring logic
      85
    end

    # Returns presented documents
    def presented_documents
      # Implement document presentation logic
      []
    end
  end
end