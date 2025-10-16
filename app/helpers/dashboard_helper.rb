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

  # Sophisticated Activity Analytics Engine
  def calculate_activity_recency_score(timestamp)
    return 0 unless timestamp

    seconds_ago = Time.current - timestamp

    case seconds_ago
    when 0..60 then 100        # Just now - maximum recency
    when 61..300 then 90       # Last 5 minutes
    when 301..900 then 80      # Last 15 minutes
    when 901..1800 then 70     # Last 30 minutes
    when 1801..3600 then 60    # Last hour
    when 3601..7200 then 50    # Last 2 hours
    when 7201..14400 then 40   # Last 4 hours
    when 14401..28800 then 30  # Last 8 hours
    when 28801..86400 then 20  # Today
    when 86401..172800 then 10 # Yesterday
    else 0                     # Older
    end
  end

  def determine_activity_urgency(activity)
    return :low unless activity

    activity_type = activity[:type]&.to_sym
    metadata = activity[:metadata] || {}

    case activity_type
    when :security_alert, :payment_issue, :dispute, :urgent_notification
      :critical
    when :order_update, :delivery, :review_request, :low_stock
      :high
    when :recommendation, :wishlist, :social, :achievement
      :medium
    else
      metadata[:priority]&.to_sym || :low
    end
  end

  def assess_contextual_relevance(activity)
    return 50 unless activity

    score = 50 # Base relevance
    activity_type = activity[:type]&.to_sym

    relevance_weights = {
      security_alert: 100,
      payment_issue: 95,
      dispute: 90,
      order_update: 85,
      delivery: 80,
      review_request: 75,
      achievement: 70,
      recommendation: 65,
      social: 60,
      wishlist: 55,
      login: 30,
      default: 50
    }

    score = relevance_weights[activity_type] || 50

    score += 10 if activity[:user_interaction]&.positive?
    score += 5 if activity[:related_to_current_page] == true
    score -= 15 if activity[:dismissed] == true

    [[score, 100].min, 0].max
  end

  def analyze_activity_pattern(activity)
    return :normal unless activity

    {
      frequency: :normal,
      recency: :normal,
      interaction_rate: :normal,
      category: :standard
    }
  end

  def compute_activity_priority_class(recency_score, urgency_level, relevance_score)
    priority = case urgency_level.to_sym
               when :critical then 'priority-critical'
               when :high then 'priority-high'
               when :medium then 'priority-medium'
               else 'priority-normal'
               end

    priority += ' recent' if recency_score > 80
    priority += ' relevant' if relevance_score > 75

    priority
  end

  def compute_staggered_animation_delay(activity)
    return 0 unless activity

    base_delay = 100
    type_delay = activity[:type].hash % 200
    position_delay = (activity[:position] || 0) * 50

    base_delay + type_delay + position_delay
  end

  def activity_container_classes(activity_type, priority_class, recency_score, behavioral_pattern)
    classes = [
      'activity-item',
      "activity-#{activity_type}",
      priority_class,
      'enhanced-activity-item'
    ]

    classes << 'activity-fresh' if recency_score > 80
    classes << 'activity-stale' if recency_score < 20
    classes << 'activity-pattern-frequent' if behavioral_pattern[:frequency] == :high

    classes.join(' ')
  end

  def activity_icon_container_classes(activity_type, urgency_level, recency_score)
    classes = [
      'activity-icon-container',
      "activity-icon-#{activity_type}",
      "urgency-#{urgency_level}"
    ]

    classes << 'recent-activity' if recency_score > 70
    classes << 'animated-icon' if recency_score > 90

    classes.join(' ')
  end

  def activity_content_classes(activity_type, relevance_score)
    classes = [
      'activity-content',
      "content-#{activity_type}"
    ]

    classes << 'high-relevance' if relevance_score > 75
    classes << 'low-relevance' if relevance_score < 25

    classes.join(' ')
  end

  def activity_title_classes(activity_type, urgency_level, relevance_score)
    classes = [
      'activity-title',
      "title-#{activity_type}",
      "urgency-#{urgency_level}"
    ]

    classes << 'emphasis' if relevance_score > 80 || urgency_level == :critical
    classes << 'subtle' if relevance_score < 30

    classes.join(' ')
  end

  def activity_meta_classes(recency_score, relevance_score)
    classes = ['activity-meta']

    classes << 'fresh-meta' if recency_score > 80
    classes << 'stale-meta' if recency_score < 30
    classes << 'relevant-meta' if relevance_score > 70

    classes.join(' ')
  end

  def activity_interaction_layer_classes
    'activity-interaction-layer progressive-disclosure'
  end

  def render_activity_custom_icon(icon, activity_type)
    content_tag :div, class: "custom-activity-icon icon-#{activity_type}" do
      concat(icon)
      concat(render_activity_urgency_pulse(activity_type))
    end
  end

  def render_activity_semantic_icon(activity_type, urgency_level, recency_score)
    icon_name = activity_semantic_icon_name(activity_type, urgency_level)
    icon_classes = "semantic-activity-icon icon-#{activity_type} urgency-#{urgency_level}"

    content_tag :div, class: icon_classes do
      concat(heroicon(icon_name, size: :sm))
      concat(render_activity_recency_indicator(recency_score)) if recency_score > 70
    end
  end

  def render_activity_state_indicators(recency_score, urgency_level, behavioral_pattern)
    indicators = []

    indicators << render_recency_pulse_indicator(recency_score)
    indicators << render_urgency_state_indicator(urgency_level)
    indicators << render_pattern_indicator(behavioral_pattern)

    content_tag :div, class: 'activity-state-indicators' do
      indicators.compact.each { |indicator| concat(indicator) }
    end
  end

  def render_temporal_recency_indicator(timestamp, recency_score)
    time_display = smart_format_activity_time(timestamp, recency_score)

    content_tag :span, class: 'temporal-indicator' do
      concat(render_recency_dot(recency_score))
      concat(time_display)
    end
  end

  def enhance_activity_meta(meta, activity_type, timestamp)
    enhanced_meta = meta

    case activity_type.to_sym
    when :order
      enhanced_meta += " • Order ##{activity[:order_id] || 'N/A'}"
    when :review
      enhanced_meta += " • #{activity[:rating] || 5}-star rating"
    when :security_alert
      enhanced_meta += " • Requires attention"
    end

    if activity[:location]
      enhanced_meta += " • #{activity[:location]}"
    end

    enhanced_meta
  end

  def render_contextual_activity_actions(activity, urgency_level)
    actions = []

    case activity[:type]&.to_sym
    when :order
      actions << link_to('View Order', '#', class: 'activity-quick-action')
      actions << link_to('Track', '#', class: 'activity-quick-action secondary')
    when :review
      actions << link_to('Respond', '#', class: 'activity-quick-action')
    when :security_alert
      actions << link_to('Review', '#', class: 'activity-quick-action urgent')
    end

    content_tag :div, class: 'contextual-actions' do
      actions.compact.each { |action| concat(action) }
    end
  end

  def render_activity_quick_actions(activity, behavioral_pattern)
    actions = []

    if behavioral_pattern[:frequency] == :high
      actions << button_tag('Pin', class: 'quick-action', data: { action: 'pin' })
    end

    actions << button_tag('Archive', class: 'quick-action secondary', data: { action: 'archive' })

    content_tag :div, class: 'activity-quick-actions' do
      actions.each { |action| concat(action) }
    end
  end

  def render_behavioral_pattern_indicators(behavioral_pattern)
    indicators = []

    case behavioral_pattern[:frequency]
    when :high
      indicators << content_tag(:span, 'Frequent', class: 'pattern-indicator frequent')
    when :low
      indicators << content_tag(:span, 'Rare', class: 'pattern-indicator rare')
    end

    content_tag :div, class: 'behavioral-indicators' do
      indicators.each { |indicator| concat(indicator) }
    end
  end

  def render_activity_context_badges(activity)
    badges = []

    badges << content_tag(:span, activity_type_label(activity[:type]), class: 'activity-badge type-badge')

    if activity[:status]
      badges << content_tag(:span, activity[:status], class: 'activity-badge status-badge')
    end

    content_tag :div, class: 'activity-context-badges' do
      badges.each { |badge| concat(badge) }
    end
  end

  def activity_accessibility_description(activity, recency_score, urgency_level)
    description = "Activity: #{activity[:title] || 'Unknown activity'}"

    if recency_score > 80
      description += ", just occurred"
    elsif recency_score < 20
      description += ", occurred some time ago"
    end

    description += ", #{urgency_level} priority" if urgency_level != :low

    description
  end

  def activity_semantic_icon_name(activity_type, urgency_level)
    icons = {
      order: 'shopping-bag',
      review: 'star',
      wishlist: 'heart',
      login: 'arrow-right-on-rectangle',
      security_alert: 'shield-exclamation',
      payment_issue: 'exclamation-triangle',
      dispute: 'scale',
      delivery: 'truck',
      achievement: 'trophy',
      social: 'users',
      recommendation: 'light-bulb'
    }

    icons[activity_type.to_sym] || 'bell'
  end

  def activity_type_label(activity_type)
    labels = {
      order: 'Order',
      review: 'Review',
      wishlist: 'Wishlist',
      login: 'Login',
      security_alert: 'Security',
      payment_issue: 'Payment',
      dispute: 'Dispute',
      delivery: 'Delivery',
      achievement: 'Achievement',
      social: 'Social',
      recommendation: 'Suggestion'
    }

    labels[activity_type.to_sym] || 'Activity'
  end

  def smart_format_activity_title(title, activity_type)
    title_with_emoji = case activity_type.to_sym
                       when :order then "🛍️ #{title}"
                       when :review then "⭐ #{title}"
                       when :security_alert then "🔐 #{title}"
                       when :achievement then "🏆 #{title}"
                       when :payment_issue then "💳 #{title}"
                       else title
                       end

    title_with_emoji
  end

  def smart_format_activity_time(timestamp, recency_score)
    return 'Just now' if recency_score > 95
    return 'Recently' if recency_score > 80

    time_ago_in_words(timestamp)
  end

  def render_recency_pulse_indicator(recency_score)
    return unless recency_score > 85

    content_tag :div, class: 'recency-pulse', data: { score: recency_score }
  end

  def render_urgency_state_indicator(urgency_level)
    return unless urgency_level.to_sym != :low

    content_tag :div, class: "urgency-indicator urgency-#{urgency_level}"
  end

  def render_pattern_indicator(behavioral_pattern)
    frequency = behavioral_pattern[:frequency]
    return unless frequency != :normal

    content_tag :div, class: "pattern-indicator pattern-#{frequency}"
  end

  def render_recency_dot(recency_score)
    return unless recency_score > 70

    content_tag :span, '•', class: 'recency-dot'
  end

  def render_activity_urgency_pulse(activity_type)
    pulse_needed = [:security_alert, :payment_issue, :dispute].include?(activity_type.to_sym)

    content_tag :div, class: 'urgency-pulse' if pulse_needed
  end

  def render_activity_recency_indicator(recency_score)
    return unless recency_score > 80

    content_tag :div, class: 'recency-indicator' do
      concat(content_tag(:span, 'NEW', class: 'recency-badge'))
    end
  end

  # Sophisticated Achievement Gamification Intelligence Engine
  def calculate_achievement_rarity_score(rarity, category)
    rarity_multipliers = {
      common: 1,
      uncommon: 2,
      rare: 4,
      epic: 8,
      legendary: 16,
      mythic: 32
    }

    category_bonuses = {
      general: 1,
      social: 1.2,
      commerce: 1.3,
      security: 1.5,
      loyalty: 1.4,
      milestone: 2.0
    }

    base_score = rarity_multipliers[rarity.to_sym] || 1
    bonus = category_bonuses[category.to_sym] || 1

    (base_score * bonus).to_i
  end

  def assess_unlock_complexity(achievement)
    return 1 unless achievement

    complexity = 1

    # Base complexity from achievement requirements
    complexity += achievement[:requirements]&.count.to_i
    complexity += achievement[:time_limit] ? 2 : 0
    complexity += achievement[:streak_required] ? 3 : 0
    complexity += achievement[:social_component] ? 2 : 0

    # Difficulty modifiers
    case achievement[:difficulty]&.to_sym
    when :easy then complexity * 1
    when :medium then complexity * 1.5
    when :hard then complexity * 2
    when :expert then complexity * 3
    else complexity * 1.2
    end

    complexity
  end

  def calculate_progress_velocity(achievement)
    return 0 unless achievement

    progress = achievement[:progress] || 0
    time_invested = achievement[:time_invested] || 1

    # Calculate progress rate per unit time
    progress.to_f / time_invested
  end

  def compute_achievement_value(points, rarity_score, unlock_complexity)
    base_value = points
    rarity_bonus = Math.log(rarity_score + 1) * 10
    complexity_multiplier = unlock_complexity * 2

    (base_value + rarity_bonus) * complexity_multiplier
  end

  def determine_presentation_mode(rarity_score, locked, progress)
    case rarity_score
    when 0..5 then :compact
    when 6..15 then :standard
    when 16..30 then :enhanced
    else :premium
    end
  end

  def select_achievement_animation_type(rarity_score, unlock_complexity)
    case rarity_score
    when 0..5 then :simple
    when 6..15 then :standard
    when 16..30 then :premium
    else :legendary
    end
  end

  def compute_interaction_level(progress, locked)
    level = 1

    level += 1 unless locked
    level += 1 if progress >= 100
    level += 1 if progress >= 75

    level
  end

  # Advanced Achievement CSS Class Generation Methods

  def achievement_container_classes(type, locked, rarity_score, presentation_mode, progress)
    classes = [
      'achievement-badge',
      "achievement-#{type}",
      "presentation-#{presentation_mode}",
      'enhanced-achievement-system'
    ]

    classes << 'achievement-locked' if locked
    classes << 'achievement-unlocked' unless locked
    classes << 'achievement-complete' if progress >= 100
    classes << 'achievement-progressing' if progress > 0 && progress < 100

    classes << 'rarity-common' if rarity_score <= 5
    classes << 'rarity-rare' if rarity_score > 5 && rarity_score <= 15
    classes << 'rarity-epic' if rarity_score > 15

    classes.join(' ')
  end

  def achievement_icon_container_classes(type, locked, rarity_score, presentation_mode)
    classes = [
      'achievement-icon-container',
      "icon-#{type}",
      "presentation-#{presentation_mode}"
    ]

    classes << 'icon-locked' if locked
    classes << 'icon-rarity-enhanced' if rarity_score > 10
    classes << 'icon-animated' if rarity_score > 20

    classes.join(' ')
  end

  def achievement_content_classes(type, presentation_mode, interaction_level)
    classes = [
      'achievement-content',
      "content-#{type}",
      "interaction-level-#{interaction_level}"
    ]

    classes << 'presentation-enhanced' if presentation_mode == :enhanced
    classes << 'presentation-premium' if presentation_mode == :premium

    classes.join(' ')
  end

  def achievement_title_classes(type, rarity_score, locked)
    classes = [
      'achievement-title',
      "title-#{type}"
    ]

    classes << 'rarity-enhanced' if rarity_score > 15
    classes << 'title-locked' if locked
    classes << 'title-unlocked' unless locked

    classes.join(' ')
  end

  def achievement_progress_classes(progress, locked)
    classes = ['achievement-progress']

    classes << 'progress-locked' if locked
    classes << 'progress-complete' if progress >= 100
    classes << 'progress-near-complete' if progress >= 75

    classes.join(' ')
  end

  def achievement_interaction_layer_classes
    'achievement-interaction-layer progressive-disclosure'
  end

  # Sophisticated Achievement Rendering Methods

  def render_achievement_custom_icon(icon, type, rarity_score, locked)
    content_tag :div, class: "custom-achievement-icon icon-#{type} rarity-#{rarity_score}" do
      concat(icon)
      concat(render_achievement_lock_overlay) if locked
      concat(render_achievement_rarity_glow(rarity_score))
    end
  end

  def render_achievement_semantic_icon(type, rarity_score, locked, progress)
    icon_name = achievement_semantic_icon_name(type, rarity_score)
    icon_classes = "semantic-achievement-icon icon-#{type} rarity-#{rarity_score}"

    content_tag :div, class: icon_classes do
      concat(heroicon(icon_name, size: :sm))
      concat(render_achievement_progress_ring(progress)) unless locked
      concat(render_achievement_lock_overlay) if locked
    end
  end

  def render_achievement_state_indicators(locked, progress, rarity_score, unlock_complexity)
    indicators = []

    indicators << render_achievement_lock_indicator(locked)
    indicators << render_achievement_progress_indicator(progress)
    indicators << render_achievement_complexity_indicator(unlock_complexity)

    content_tag :div, class: 'achievement-state-indicators' do
      indicators.compact.each { |indicator| concat(indicator) }
    end
  end

  def render_achievement_rarity_indicators(rarity_score, category)
    indicators = []

    indicators << render_achievement_rarity_stars(rarity_score)
    indicators << render_achievement_category_indicator(category)

    content_tag :div, class: 'achievement-rarity-indicators' do
      indicators.compact.each { |indicator| concat(indicator) }
    end
  end

  def render_unlock_progress_indicator(progress, locked, progress_velocity)
    return if locked

    content_tag :div, class: 'unlock-progress-container' do
      concat(content_tag(:div, '', class: 'progress-bar', style: "width: #{progress}%"))
      concat(content_tag(:span, "#{progress}%", class: 'progress-text'))
      concat(render_progress_velocity_indicator(progress_velocity))
    end
  end

  def render_achievement_value_display(points, achievement_value, rarity_score)
    content_tag :div, class: 'achievement-value-display' do
      concat(content_tag(:span, points, class: 'points-display'))
      concat(content_tag(:span, achievement_value.round, class: 'value-display')) if rarity_score > 10
    end
  end

  def enhance_achievement_description(description, type, rarity_score)
    enhanced_description = description

    # Add contextual information based on achievement type
    case type.to_sym
    when :streak
      enhanced_description += " Maintain your activity streak to unlock."
    when :social
      enhanced_description += " Connect and engage with other users."
    when :commerce
      enhanced_description += " Complete transactions and purchases."
    when :security
      enhanced_description += " Strengthen your account security."
    end

    # Add rarity-based enhancement
    if rarity_score > 20
      enhanced_description += " This is a highly prestigious achievement."
    end

    enhanced_description
  end

  def render_achievement_detailed_preview(achievement, unlock_complexity)
    preview_items = []

    preview_items << content_tag(:div, achievement[:description], class: 'preview-description')
    preview_items << content_tag(:div, "Difficulty: #{unlock_complexity.round(1)}/10", class: 'preview-difficulty')

    if achievement[:rewards]
      preview_items << content_tag(:div, achievement[:rewards].join(', '), class: 'preview-rewards')
    end

    content_tag :div, class: 'achievement-detailed-preview' do
      preview_items.compact.each { |item| concat(item) }
    end
  end

  def render_achievement_quick_actions(achievement, locked, progress)
    actions = []

    if locked
      actions << button_tag('View Requirements', class: 'quick-action', data: { action: 'view-requirements' })
    else
      actions << button_tag('Share', class: 'quick-action', data: { action: 'share' }) if progress >= 100
      actions << button_tag('Track Progress', class: 'quick-action secondary', data: { action: 'track' })
    end

    content_tag :div, class: 'achievement-quick-actions' do
      actions.each { |action| concat(action) }
    end
  end

  def render_unlock_progression_indicators(achievement, progress_velocity)
    indicators = []

    if progress_velocity > 0
      indicators << content_tag(:span, "Progressing rapidly", class: 'progression-indicator positive')
    elsif progress_velocity == 0
      indicators << content_tag(:span, "Start progressing", class: 'progression-indicator neutral')
    else
      indicators << content_tag(:span, "Slow progress", class: 'progression-indicator caution')
    end

    content_tag :div, class: 'unlock-progression-indicators' do
      indicators.each { |indicator| concat(indicator) }
    end
  end

  def render_achievement_context_badges(achievement, rarity_score, category)
    badges = []

    # Rarity badge
    badges << content_tag(:span, rarity_label(rarity_score), class: 'achievement-badge rarity-badge')

    # Category badge
    badges << content_tag(:span, category_label(category), class: 'achievement-badge category-badge')

    content_tag :div, class: 'achievement-context-badges' do
      badges.each { |badge| concat(badge) }
    end
  end

  def achievement_accessibility_description(title, locked, progress, rarity_score)
    description = "Achievement: #{title}"

    description += ", locked" if locked
    description += ", #{progress}% complete" if progress > 0 && progress < 100
    description += ", completed" if progress >= 100

    description += ", #{rarity_label(rarity_score)} rarity"

    description
  end

  def achievement_detailed_accessibility_description(achievement, progress, rarity_score, unlock_complexity)
    description = achievement_accessibility_description(achievement[:title], achievement[:locked], progress, rarity_score)

    description += ". Difficulty level: #{unlock_complexity.round(1)} out of 10"
    description += ". Points value: #{achievement[:points] || 0}"

    description
  end

  # Supporting utility methods for achievements

  def achievement_semantic_icon_name(type, rarity_score)
    icons = {
      streak: 'fire',
      social: 'users',
      commerce: 'shopping-bag',
      security: 'shield-check',
      loyalty: 'heart',
      milestone: 'trophy',
      challenge: 'bolt',
      exploration: 'map',
      creativity: 'light-bulb',
      consistency: 'clock'
    }

    icons[type.to_sym] || 'star'
  end

  def rarity_label(rarity_score)
    case rarity_score
    when 0..5 then 'Common'
    when 6..15 then 'Rare'
    when 16..30 then 'Epic'
    when 31..50 then 'Legendary'
    else 'Mythic'
    end
  end

  def category_label(category)
    labels = {
      general: 'General',
      social: 'Social',
      commerce: 'Commerce',
      security: 'Security',
      loyalty: 'Loyalty',
      milestone: 'Milestone',
      challenge: 'Challenge',
      exploration: 'Exploration',
      creativity: 'Creative',
      consistency: 'Consistent'
    }

    labels[category.to_sym] || 'General'
  end

  def smart_format_achievement_title(title, type, rarity_score)
    # Intelligent title formatting based on context and rarity
    emoji = achievement_type_emoji(type)
    rarity_prefix = rarity_title_prefix(rarity_score)

    formatted_title = title
    formatted_title = "#{rarity_prefix} #{formatted_title}" if rarity_prefix.present?
    formatted_title = "#{emoji} #{formatted_title}" if emoji.present?

    formatted_title
  end

  def achievement_type_emoji(type)
    emojis = {
      streak: '🔥',
      social: '👥',
      commerce: '🛍️',
      security: '🔒',
      loyalty: '💎',
      milestone: '🏆',
      challenge: '⚡',
      exploration: '🗺️',
      creativity: '💡',
      consistency: '⏰'
    }

    emojis[type.to_sym]
  end

  def rarity_title_prefix(rarity_score)
    case rarity_score
    when 16..30 then 'Epic'
    when 31..50 then 'Legendary'
    when 51..100 then 'Mythic'
    else ''
    end
  end

  def render_achievement_lock_overlay
    content_tag :div, class: 'achievement-lock-overlay' do
      concat(heroicon('lock-closed', size: :sm))
    end
  end

  def render_achievement_rarity_glow(rarity_score)
    return unless rarity_score > 15

    content_tag :div, class: "rarity-glow rarity-#{rarity_score}", data: { intensity: rarity_score }
  end

  def render_achievement_progress_ring(progress)
    content_tag :div, class: 'achievement-progress-ring' do
      concat(content_tag(:svg, class: 'progress-ring-svg') do
        concat(content_tag(:circle, '', class: 'progress-ring-circle', style: "stroke-dasharray: #{progress * 2.51};"))
      end)
    end
  end

  def render_achievement_lock_indicator(locked)
    return unless locked

    content_tag :div, class: 'achievement-lock-indicator' do
      concat(heroicon('lock-closed', size: :xs))
    end
  end

  def render_achievement_progress_indicator(progress)
    return if progress == 0

    content_tag :div, class: 'achievement-progress-indicator' do
      concat(content_tag(:span, "#{progress}%", class: 'progress-text'))
    end
  end

  def render_achievement_complexity_indicator(unlock_complexity)
    return if unlock_complexity <= 1

    difficulty_level = case unlock_complexity
                      when 1..3 then :easy
                      when 4..6 then :medium
                      when 7..9 then :hard
                      else :expert
                      end

    content_tag :div, class: "complexity-indicator difficulty-#{difficulty_level}"
  end

  def render_achievement_rarity_stars(rarity_score)
    star_count = case rarity_score
                 when 0..5 then 1
                 when 6..15 then 2
                 when 16..30 then 3
                 when 31..50 then 4
                 else 5
                 end

    content_tag :div, class: 'rarity-stars' do
      star_count.times { concat(content_tag(:span, '★', class: 'rarity-star')) }
    end
  end

  def render_achievement_category_indicator(category)
    content_tag :div, class: "category-indicator category-#{category}"
  end

  def render_progress_velocity_indicator(progress_velocity)
    return unless progress_velocity > 0

    velocity_class = case progress_velocity
                     when 0..0.1 then 'velocity-slow'
                     when 0.1..0.5 then 'velocity-normal'
                     else 'velocity-fast'
                     end

    content_tag :span, class: "progress-velocity-indicator #{velocity_class}"
  end

  def render_achievement_unlock_effects(rarity_score, animation_type)
    effects = []

    case animation_type
    when :premium
      effects << content_tag(:div, class: 'unlock-sparkles')
      effects << content_tag(:div, class: 'unlock-glow')
    when :legendary
      effects << content_tag(:div, class: 'unlock-fireworks')
      effects << content_tag(:div, class: 'unlock-radiance')
    end

    content_tag :div, class: 'achievement-unlock-effects' do
      effects.each { |effect| concat(effect) }
    end
  end
end