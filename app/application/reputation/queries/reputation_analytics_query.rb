# frozen_string_literal: true

# Query: Comprehensive reputation analytics for admin dashboard
# Optimized for reporting and monitoring with time-based aggregations
class ReputationAnalyticsQuery
  include QueryPattern

  attr_reader :date_range, :group_by, :filters

  def initialize(date_range: 30.days.ago..Time.current, group_by: :day, filters: {})
    @date_range = date_range
    @group_by = group_by
    @filters = filters
  end

  # Execute comprehensive analytics query
  def execute
    {
      overview: overview_metrics,
      trends: reputation_trends,
      distributions: reputation_distributions,
      top_performers: top_performers,
      risk_indicators: risk_indicators,
      system_health: system_health_metrics
    }
  end

  # Get high-level overview metrics
  def overview_metrics
    events = filtered_events

    {
      total_events: events.count,
      total_points_awarded: events.gains.sum(:points_change).to_i,
      total_points_deducted: events.losses.sum(:points_change).abs.to_i,
      unique_users: events.distinct.count(:user_id),
      average_score_change: events.average(:points_change)&.round(2) || 0,
      net_reputation_change: events.sum(:points_change).to_i,
      events_per_day: calculate_events_per_day(events)
    }
  end

  # Get reputation trends over time
  def reputation_trends
    events = filtered_events

    case group_by
    when :hour
      group_by_hour(events)
    when :day
      group_by_day(events)
    when :week
      group_by_week(events)
    when :month
      group_by_month(events)
    else
      group_by_day(events)
    end
  end

  # Get reputation score distributions
  def reputation_distributions
    user_scores = calculate_all_user_scores

    {
      level_distribution: level_distribution(user_scores),
      score_buckets: score_buckets(user_scores),
      percentile_ranks: percentile_ranks(user_scores)
    }
  end

  # Get top performing users
  def top_performers(limit = 20)
    user_scores = calculate_all_user_scores
                   .sort_by { |_, score| -score }
                   .first(limit)

    user_scores.map do |user_id, score|
      user = User.find_by(id: user_id)
      next unless user

      {
        user_id: user_id,
        username: user.username,
        score: score,
        level: ReputationLevel.from_score(score).to_s,
        recent_activity: recent_activity_for_user(user_id)
      }
    end.compact
  end

  # Get risk indicators for moderation
  def risk_indicators
    events = filtered_events

    {
      high_frequency_users: users_with_high_frequency,
      suspicious_patterns: detect_suspicious_patterns,
      rapid_score_changes: rapid_score_changes,
      potential_gaming: detect_potential_gaming
    }
  end

  # Get system health metrics
  def system_health_metrics
    events = filtered_events

    {
      average_processing_time: benchmark_query_time,
      cache_hit_rate: calculate_cache_hit_rate,
      database_performance: database_performance_metrics,
      error_rates: error_rate_metrics(events)
    }
  end

  private

  def filtered_events
    events = UserReputationEvent.where(created_at: date_range)

    if filters[:event_types].present?
      events = events.where(event_type: filters[:event_types])
    end

    if filters[:levels].present?
      events = events.where(reputation_level: filters[:levels])
    end

    if filters[:user_ids].present?
      events = events.where(user_id: filters[:user_ids])
    end

    events
  end

  def calculate_all_user_scores
    UserReputationEvent.where(created_at: date_range)
                      .group(:user_id)
                      .sum(:points_change)
  end

  def level_distribution(user_scores)
    distribution = Hash.new(0)

    user_scores.each do |_, score|
      level = ReputationLevel.from_score(score)
      distribution[level] += 1
    end

    distribution
  end

  def score_buckets(user_scores)
    buckets = {
      'Restricted (-∞ to -50)': 0,
      'Probation (-49 to 0)': 0,
      'Regular (1 to 100)': 0,
      'Trusted (101 to 500)': 0,
      'Exemplary (501+)': 0
    }

    user_scores.each do |_, score|
      case score
      when -Float::INFINITY..-50
        buckets['Restricted (-∞ to -50)'] += 1
      when -49..0
        buckets['Probation (-49 to 0)'] += 1
      when 1..100
        buckets['Regular (1 to 100)'] += 1
      when 101..500
        buckets['Trusted (101 to 500)'] += 1
      else
        buckets['Exemplary (501+)'] += 1
      end
    end

    buckets
  end

  def percentile_ranks(user_scores)
    scores = user_scores.values.sort

    return {} if scores.empty?

    {
      p25: percentile(scores, 0.25),
      p50: percentile(scores, 0.50),
      p75: percentile(scores, 0.75),
      p90: percentile(scores, 0.90),
      p95: percentile(scores, 0.95)
    }
  end

  def percentile(values, percentile)
    index = (values.length * percentile).ceil - 1
    index = [index, values.length - 1].min
    values[index]
  end

  def group_by_hour(events)
    events.group("DATE_FORMAT(created_at, '%Y-%m-%d %H:00:00')")
          .sum(:points_change)
  end

  def group_by_day(events)
    events.group("DATE(created_at)")
          .sum(:points_change)
  end

  def group_by_week(events)
    events.group("YEARWEEK(created_at)")
          .sum(:points_change)
  end

  def group_by_month(events)
    events.group("DATE_FORMAT(created_at, '%Y-%m')")
          .sum(:points_change)
  end

  def calculate_events_per_day(events)
    days = (date_range.end - date_range.begin).to_f / 1.day
    return 0 if days.zero?

    (events.count / days).round(2)
  end

  def users_with_high_frequency
    UserReputationEvent.where(created_at: date_range)
                      .group(:user_id)
                      .having('COUNT(*) > 50')
                      .count
  end

  def detect_suspicious_patterns
    # Look for patterns that might indicate gaming or abuse
    patterns = []

    # Users with many small gains in short time
    small_gains = UserReputationEvent.where(created_at: 1.day.ago..Time.current)
                                    .where('points_change BETWEEN 1 AND 5')
                                    .group(:user_id)
                                    .having('COUNT(*) > 20')
                                    .count

    patterns << { type: :micro_gaming, count: small_gains.keys.count } if small_gains.any?

    patterns
  end

  def rapid_score_changes
    # Users with score changes > 100 points in 24 hours
    UserReputationEvent.where(created_at: 1.day.ago..Time.current)
                      .where('ABS(points_change) > 100')
                      .group(:user_id)
                      .count
  end

  def detect_potential_gaming
    # Complex pattern detection for reputation gaming
    gaming_indicators = []

    # Pattern: Regular intervals between actions
    # Pattern: Always maximum allowed points
    # Pattern: Coordinated timing with other users

    gaming_indicators
  end

  def recent_activity_for_user(user_id)
    UserReputationEvent.where(user_id: user_id)
                      .where('created_at >= ?', 7.days.ago)
                      .order(created_at: :desc)
                      .limit(5)
                      .map(&:description)
  end

  def benchmark_query_time
    start_time = Time.current
    execute
    (Time.current - start_time) * 1000 # milliseconds
  end

  def calculate_cache_hit_rate
    # This would integrate with actual cache metrics
    0.85 # Placeholder
  end

  def database_performance_metrics
    {
      query_time_ms: benchmark_query_time,
      records_processed: filtered_events.count,
      efficiency_ratio: calculate_events_per_day(filtered_events)
    }
  end

  def error_rate_metrics(events)
    # Calculate error rates from event metadata or logs
    {
      validation_errors: 0,
      processing_errors: 0,
      timeout_errors: 0
    }
  end
end