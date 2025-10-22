# frozen_string_literal: true

# Service: Handles complex reputation calculation algorithms
# Implements sophisticated scoring mechanisms with decay, multipliers, and contextual weighting
class ReputationCalculationService
  include ServicePattern

  # Configuration for reputation calculations
  REPUTATION_CONFIG = {
    max_daily_gain: 100,
    max_daily_loss: 50,
    decay_rate: 0.95, # Daily decay factor
    activity_bonus_threshold: 7, # Days of consecutive activity
    quality_multiplier_max: 2.0,
    recency_weight: 0.8,
    base_action_scores: {
      purchase_completion: 10,
      review_submission: 5,
      helpful_vote: 2,
      content_creation: 8,
      moderation_action: 3,
      bug_report: 15,
      referral: 20
    },
    violation_penalties: {
      spam: 10,
      harassment: 25,
      fraud: 50,
      scam: 100,
      inappropriate_content: 15,
      policy_violation: 20
    }
  }.freeze

  attr_reader :user_id, :context

  def initialize(user_id, context = {})
    @user_id = user_id
    @context = context
  end

  # Calculate reputation points for a specific action
  def calculate_action_points(action_type, metadata = {})
    base_points = base_points_for_action(action_type)
    return 0 if base_points.zero?

    # Apply quality multiplier based on action quality
    quality_multiplier = calculate_quality_multiplier(action_type, metadata)

    # Apply recency bonus for recent activity
    recency_multiplier = calculate_recency_multiplier

    # Apply user history multiplier
    history_multiplier = calculate_history_multiplier

    # Apply contextual adjustments
    contextual_multiplier = calculate_contextual_multiplier(action_type, metadata)

    # Calculate final points
    raw_points = base_points * quality_multiplier * recency_multiplier * history_multiplier * contextual_multiplier

    # Apply daily limits
    apply_daily_limits(raw_points, action_type)
  end

  # Calculate reputation decay for inactive users
  def calculate_decay_points(days_inactive)
    return 0 if days_inactive <= 0

    user_score = current_reputation_score
    return 0 if user_score <= 0

    # Exponential decay based on inactivity
    decay_factor = REPUTATION_CONFIG[:decay_rate] ** days_inactive
    decay_amount = user_score * (1 - decay_factor)

    # Don't decay below zero
    [decay_amount, user_score].min.to_i
  end

  # Calculate reputation bonus for consistent activity
  def calculate_activity_bonus
    streak_days = calculate_current_activity_streak

    return 0 if streak_days < REPUTATION_CONFIG[:activity_bonus_threshold]

    # Bonus increases with streak length
    bonus_multiplier = 1 + (Math.log(streak_days) / 10)
    base_bonus = 5

    (base_bonus * bonus_multiplier).to_i
  end

  # Calculate reputation penalty for violations
  def calculate_violation_penalty(violation_type, severity = 'medium', context = {})
    base_penalty = REPUTATION_CONFIG[:violation_penalties][violation_type.to_sym] || 10

    # Apply severity multiplier
    severity_multiplier = case severity.to_sym
                         when :low then 0.5
                         when :medium then 1.0
                         when :high then 1.5
                         when :critical then 2.0
                         else 1.0
                         end

    # Apply context multipliers
    context_multiplier = calculate_violation_context_multiplier(context)

    # Apply user history factor (repeat offenders get harsher penalties)
    history_multiplier = calculate_violation_history_multiplier

    raw_penalty = base_penalty * severity_multiplier * context_multiplier * history_multiplier

    # Apply daily limits
    apply_daily_limits(-raw_penalty.abs, :violation)
  end

  # Calculate level progression requirements
  def calculate_level_progression(current_score)
    current_level = ReputationLevel.from_score(current_score)

    case current_level
    when :restricted
      { next_level: :probation, points_needed: 50 - current_score }
    when :probation
      { next_level: :regular, points_needed: 1 - current_score }
    when :regular
      { next_level: :trusted, points_needed: 101 - current_score }
    when :trusted
      { next_level: :exemplary, points_needed: 501 - current_score }
    else
      { next_level: nil, points_needed: 0 }
    end
  end

  # Calculate reputation velocity (rate of change)
  def calculate_reputation_velocity(days = 30)
    events = reputation_events_in_period(days)

    return 0.0 if events.empty?

    total_change = events.sum(:points_change)
    (total_change.to_f / days).round(2)
  end

  # Calculate reputation stability score
  def calculate_stability_score(days = 30)
    events = reputation_events_in_period(days)

    return 100.0 if events.empty?

    # Calculate variance in daily changes
    daily_changes = events.group("DATE(created_at)").sum(:points_change)
    return 100.0 if daily_changes.size <= 1

    mean = daily_changes.values.sum.to_f / daily_changes.size
    variance = daily_changes.values.sum { |change| (change - mean) ** 2 } / daily_changes.size

    # Convert variance to stability score (lower variance = higher stability)
    stability = [100 - Math.sqrt(variance), 0].max
    stability.round(1)
  end

  private

  def base_points_for_action(action_type)
    REPUTATION_CONFIG[:base_action_scores][action_type.to_sym] || 0
  end

  def calculate_quality_multiplier(action_type, metadata)
    case action_type.to_sym
    when :review_submission
      calculate_review_quality(metadata)
    when :content_creation
      calculate_content_quality(metadata)
    when :moderation_action
      calculate_moderation_quality(metadata)
    else
      1.0
    end
  end

  def calculate_review_quality(metadata)
    quality_score = 1.0

    # Length bonus
    length = metadata[:review_length] || 0
    quality_score *= 1.2 if length > 200
    quality_score *= 1.1 if length > 100

    # Detail bonus
    has_images = metadata[:has_images] || false
    quality_score *= 1.3 if has_images

    # Helpfulness based on votes
    helpful_votes = metadata[:helpful_votes] || 0
    quality_score *= 1.2 if helpful_votes > 5

    # Verified purchase bonus
    verified_purchase = metadata[:verified_purchase] || false
    quality_score *= 1.4 if verified_purchase

    quality_score
  end

  def calculate_content_quality(metadata)
    quality_score = 1.0

    # Originality check
    originality_score = metadata[:originality_score] || 0.5
    quality_score *= (0.8 + originality_score * 0.4)

    # Engagement metrics
    views = metadata[:views] || 0
    quality_score *= 1.2 if views > 100

    likes = metadata[:likes] || 0
    quality_score *= 1.1 if likes > 10

    # Content length and depth
    word_count = metadata[:word_count] || 0
    quality_score *= 1.2 if word_count > 500

    quality_score
  end

  def calculate_moderation_quality(metadata)
    accuracy = metadata[:accuracy_score] || 0.5
    0.8 + (accuracy * 0.4) # Scale from 0.8 to 1.2
  end

  def calculate_recency_multiplier
    # Bonus for recent activity (within last 7 days)
    recent_events = UserReputationEvent.where(user_id: user_id)
                                      .where('created_at >= ?', 7.days.ago)
                                      .count

    return 1.0 if recent_events.zero?

    # Diminishing returns for very high activity
    Math.log(recent_events + 1) * REPUTATION_CONFIG[:recency_weight] + 1
  end

  def calculate_history_multiplier
    total_score = current_reputation_score
    event_count = total_reputation_events

    return 1.0 if event_count < 10

    # Experienced users get slight bonus for consistent behavior
    consistency_bonus = calculate_consistency_score
    0.9 + (consistency_bonus * 0.2)
  end

  def calculate_contextual_multiplier(action_type, metadata)
    multiplier = 1.0

    # Time-based multipliers
    hour = Time.current.hour
    if hour.between?(9, 17) # Business hours bonus
      multiplier *= 1.1
    elsif hour.between?(22, 6) # Late night penalty
      multiplier *= 0.9
    end

    # Platform activity multiplier
    platform_activity = metadata[:platform_activity_score] || 1.0
    multiplier *= platform_activity

    multiplier
  end

  def calculate_violation_context_multiplier(context)
    multiplier = 1.0

    # Repeat offense multiplier
    recent_violations = context[:recent_violations] || 0
    multiplier *= (1 + recent_violations * 0.2)

    # Impact severity
    impact_level = context[:impact_level] || 'medium'
    case impact_level.to_sym
    when :low then multiplier *= 0.8
    when :high then multiplier *= 1.3
    when :critical then multiplier *= 1.5
    end

    multiplier
  end

  def calculate_violation_history_multiplier
    recent_violations = UserReputationEvent.where(user_id: user_id)
                                          .where(event_type: :reputation_lost)
                                          .where('created_at >= ?', 90.days.ago)
                                          .count

    # Repeat offenders get harsher penalties
    1 + (recent_violations * 0.1)
  end

  def apply_daily_limits(points, action_type)
    today = Date.current
    today_events = UserReputationEvent.where(user_id: user_id)
                                     .where('DATE(created_at) = ?', today)

    if points.positive?
      today_gains = today_events.gains.sum(:points_change)
      max_gain = REPUTATION_CONFIG[:max_daily_gain]

      return 0 if today_gains >= max_gain

      available_gain = max_gain - today_gains
      [points, available_gain].min
    else
      today_losses = today_events.losses.sum(:points_change).abs
      max_loss = REPUTATION_CONFIG[:max_daily_loss]

      return 0 if today_losses >= max_loss

      available_loss = max_loss - today_losses
      [-points.abs, available_loss].min * -1 # Return negative value
    end
  end

  def current_reputation_score
    @current_score ||= UserReputationEvent.where(user_id: user_id).sum(:points_change)
  end

  def total_reputation_events
    @total_events ||= UserReputationEvent.where(user_id: user_id).count
  end

  def reputation_events_in_period(days)
    UserReputationEvent.where(user_id: user_id)
                      .where('created_at >= ?', days.days.ago)
  end

  def calculate_current_activity_streak
    events = UserReputationEvent.where(user_id: user_id)
                               .where('points_change > 0')
                               .order(created_at: :desc)

    streak = 0
    last_date = nil

    events.each do |event|
      event_date = event.created_at.to_date

      if last_date.nil? || event_date == last_date.yesterday
        streak += 1
      else
        break
      end

      last_date = event_date
    end

    streak
  end

  def calculate_consistency_score
    # Calculate how consistent the user's reputation gains are
    recent_events = reputation_events_in_period(30)
    return 0.5 if recent_events.empty?

    changes = recent_events.pluck(:points_change)
    mean = changes.sum.to_f / changes.size
    variance = changes.sum { |change| (change - mean) ** 2 } / changes.size

    # Lower variance = higher consistency
    consistency = [1 - (variance / 100), 0].max
    consistency.round(2)
  end
end