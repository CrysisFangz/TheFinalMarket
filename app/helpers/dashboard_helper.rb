# frozen_string_literal: true

# DashboardHelper - Helper methods for dashboard-specific functionality
module DashboardHelper
  # Get appropriate icon color class for activity type
  def activity_icon_color(activity_type)
    case activity_type.to_sym
    when :order
      'activity-icon-blue'
    when :review
      'activity-icon-purple'
    when :wishlist
      'activity-icon-pink'
    when :login
      'activity-icon-green'
    else
      'activity-icon-gray'
    end
  end

  # Format dashboard statistics with proper number formatting
  def format_dashboard_stat(value, type: :number)
    case type
    when :currency
      number_to_currency(value, precision: 0)
    when :percentage
      number_to_percentage(value, precision: 1)
    else
      number_with_delimiter(value)
    end
  end

  # Get trend indicator for dashboard stats
  def trend_indicator(current, previous, **options)
    return '' if previous.zero?

    percentage_change = ((current - previous) / previous.to_f * 100).round
    direction = percentage_change.positive? ? :up : :down
    color = percentage_change.positive? ? 'positive' : 'negative'

    content_tag :div, class: "stat-change #{color}", **options do
      concat(icon("chevron-#{direction}", size: 'w-4 h-4', aria_hidden: true))
      concat(" #{percentage_change.abs}% this month")
    end
  end

  # Generate dashboard widget wrapper with consistent structure
  def dashboard_widget(title, icon_name: nil, **options)
    content_tag :div, class: 'widget-card', **options do
      yield
    end
  end

  # Format time ago in a human-readable way for dashboard
  def dashboard_time_ago(time)
    return 'Never' unless time

    time_ago_in_words(time)
  end

  # Get status badge class for orders
  def order_status_class(status)
    case status.to_sym
    when :pending, :processing
      'status-yellow'
    when :shipped, :delivered
      'status-green'
    when :cancelled
      'status-red'
    else
      'status-gray'
    end
  end

  # Generate security score based on user settings
  def calculate_security_score(user)
    score = 0
    score += 25 if user.email_verified?
    score += 25 if user.two_factor_enabled?
    score += 25 # Assume password is strong
    score += 25 if user.last_sign_in_at&.>=(30.days.ago)

    score
  end

  # Get appropriate greeting based on time of day
  def time_based_greeting
    hour = Time.current.hour

    case hour
    when 5..11
      'Good morning'
    when 12..16
      'Good afternoon'
    when 17..21
      'Good evening'
    else
      'Hello'
    end
  end

  # Format user display name with fallbacks
  def user_display_name(user)
    return 'Friend' unless user

    user.name.presence || user.email.split('@').first.presence || 'User'
  end
end