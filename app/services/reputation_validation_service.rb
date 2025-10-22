# frozen_string_literal: true

# Service: Validates reputation operations and enforces business rules
# Ensures data integrity and prevents reputation system abuse
class ReputationValidationService
  include ServicePattern

  # Validation rule sets
  VALIDATION_RULES = {
    max_points_per_action: 100,
    max_actions_per_hour: 20,
    max_actions_per_day: 100,
    min_hours_between_similar_actions: 1,
    max_negative_actions_per_day: 5,
    suspicious_patterns: {
      identical_timings: 3,
      rapid_fire_actions: 10,
      coordinated_group_actions: 5
    }
  }.freeze

  attr_reader :user_id, :action_type, :metadata

  def initialize(user_id, action_type, metadata = {})
    @user_id = user_id
    @action_type = action_type
    @metadata = metadata
  end

  # Validate a reputation action before execution
  def validate_action
    validations = [
      :validate_user_exists,
      :validate_action_type,
      :validate_points_limits,
      :validate_frequency_limits,
      :validate_timing_requirements,
      :validate_user_restrictions,
      :validate_suspicious_patterns,
      :validate_context_constraints
    ]

    errors = []

    validations.each do |validation|
      result = send(validation)
      errors << result if result.is_a?(String)
    end

    errors.empty? ? nil : errors
  end

  # Validate reputation penalty before applying
  def validate_penalty(violation_type, severity, context = {})
    validations = [
      :validate_penalty_user,
      :validate_violation_type,
      :validate_severity_level,
      :validate_penalty_frequency,
      :validate_penalty_context
    ]

    errors = []

    validations.each do |validation|
      result = send(validation, violation_type, severity, context)
      errors << result if result.is_a?(String)
    end

    errors.empty? ? nil : errors
  end

  # Check if user can perform reputation actions
  def can_user_act?
    return false unless user_exists?
    return false if user_restricted?
    return false if user_rate_limited?

    true
  end

  # Get user's current rate limit status
  def rate_limit_status
    hourly_count = actions_in_period(1.hour.ago)
    daily_count = actions_in_period(1.day.ago)

    {
      hourly_used: hourly_count,
      hourly_limit: VALIDATION_RULES[:max_actions_per_hour],
      daily_used: daily_count,
      daily_limit: VALIDATION_RULES[:max_actions_per_day],
      next_reset: next_reset_time
    }
  end

  private

  def validate_user_exists
    return 'User not found' unless User.exists?(user_id)
    nil
  end

  def validate_action_type
    valid_actions = %i[
      purchase_completion review_submission helpful_vote content_creation
      moderation_action bug_report referral social_share
    ]

    return 'Invalid action type' unless valid_actions.include?(action_type.to_sym)
    nil
  end

  def validate_points_limits
    points = metadata[:points] || 0

    if points.negative? && negative_actions_today >= VALIDATION_RULES[:max_negative_actions_per_day]
      return 'Daily negative action limit exceeded'
    end

    if points.abs > VALIDATION_RULES[:max_points_per_action]
      return 'Points exceed maximum allowed per action'
    end

    nil
  end

  def validate_frequency_limits
    hourly_count = actions_in_period(1.hour.ago)
    daily_count = actions_in_period(1.day.ago)

    if hourly_count >= VALIDATION_RULES[:max_actions_per_hour]
      return 'Hourly action limit exceeded'
    end

    if daily_count >= VALIDATION_RULES[:max_actions_per_day]
      return 'Daily action limit exceeded'
    end

    nil
  end

  def validate_timing_requirements
    return nil unless metadata[:previous_action_at]

    time_since_last = Time.current - metadata[:previous_action_at]

    if time_since_last < VALIDATION_RULES[:min_hours_between_similar_actions].hours
      return 'Actions too frequent'
    end

    nil
  end

  def validate_user_restrictions
    user = User.find(user_id)

    if user.reputation_level == 'restricted'
      return 'User is restricted from reputation actions'
    end

    if user.reputation_score < -100
      return 'User reputation too low for actions'
    end

    nil
  end

  def validate_suspicious_patterns
    # Check for rapid-fire identical actions
    recent_identical = recent_identical_actions

    if recent_identical >= VALIDATION_RULES[:suspicious_patterns][:identical_timings]
      return 'Suspicious pattern: identical actions'
    end

    # Check for rapid-fire actions
    recent_rapid = actions_in_period(5.minutes.ago)

    if recent_rapid >= VALIDATION_RULES[:suspicious_patterns][:rapid_fire_actions]
      return 'Suspicious pattern: rapid fire actions'
    end

    nil
  end

  def validate_context_constraints
    # Validate based on context-specific rules
    case action_type.to_sym
    when :review_submission
      validate_review_context
    when :content_creation
      validate_content_context
    when :moderation_action
      validate_moderation_context
    else
      nil
    end
  end

  def validate_penalty_user
    return 'User not found' unless User.exists?(user_id)
    nil
  end

  def validate_violation_type
    valid_violations = %w[spam harassment fraud scam inappropriate_content policy_violation]

    return 'Invalid violation type' unless valid_violations.include?(metadata[:violation_type])
    nil
  end

  def validate_severity_level
    valid_severities = %w[low medium high critical]

    return 'Invalid severity level' unless valid_severities.include?(metadata[:severity_level])
    nil
  end

  def validate_penalty_frequency
    recent_penalties = UserReputationEvent.where(user_id: user_id)
                                         .where(event_type: :reputation_lost)
                                         .where('created_at >= ?', 1.hour.ago)
                                         .count

    if recent_penalties >= 3
      return 'Too many recent penalties'
    end

    nil
  end

  def validate_penalty_context
    # Validate penalty context doesn't conflict with business rules
    user = User.find(user_id)

    # Don't penalize users who are already at minimum reputation
    if user.reputation_score <= -200
      return 'User already at minimum reputation'
    end

    nil
  end

  def user_exists?
    User.exists?(user_id)
  end

  def user_restricted?
    user = User.find_by(id: user_id)
    return false unless user

    user.reputation_level == 'restricted'
  end

  def user_rate_limited?
    hourly_count = actions_in_period(1.hour.ago)
    daily_count = actions_in_period(1.day.ago)

    hourly_count >= VALIDATION_RULES[:max_actions_per_hour] ||
    daily_count >= VALIDATION_RULES[:max_actions_per_day]
  end

  def actions_in_period(since)
    UserReputationEvent.where(user_id: user_id)
                      .where('created_at >= ?', since)
                      .count
  end

  def negative_actions_today
    UserReputationEvent.where(user_id: user_id)
                      .where('points_change < 0')
                      .where('DATE(created_at) = ?', Date.current)
                      .count
  end

  def recent_identical_actions
    UserReputationEvent.where(user_id: user_id)
                      .where(action_type: action_type)
                      .where('created_at >= ?', 10.minutes.ago)
                      .count
  end

  def next_reset_time
    # Next hour for hourly reset
    1.hour.from_now.beginning_of_hour
  end

  def validate_review_context
    # Specific validation for reviews
    if metadata[:product_id] && metadata[:user_id] == metadata[:product_seller_id]
      return 'Cannot review own products'
    end

    # Check for duplicate reviews
    existing_review = UserReputationEvent.where(
      user_id: user_id,
      source_type: 'review',
      source_id: metadata[:product_id]
    ).exists?

    return 'Duplicate review not allowed' if existing_review

    nil
  end

  def validate_content_context
    # Specific validation for content creation
    if metadata[:content_type] == 'comment' && metadata[:parent_content_id].blank?
      return 'Comment must reference parent content'
    end

    nil
  end

  def validate_moderation_context
    # Specific validation for moderation actions
    user = User.find(user_id)

    unless user.reputation_level.in?(%w[trusted exemplary])
      return 'Insufficient reputation for moderation'
    end

    nil
  end
end