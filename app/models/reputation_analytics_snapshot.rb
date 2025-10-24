# frozen_string_literal: true

# Read Model: Pre-calculated reputation analytics for fast dashboard queries
# Materialized view of reputation metrics updated periodically
class ReputationAnalyticsSnapshot < ApplicationRecord
  # Table configuration
  self.table_name = 'reputation_analytics_snapshots'
  self.primary_key = 'id'

  # Attributes for analytics data
  attribute :snapshot_date, :date
  attribute :total_users, :integer
  attribute :active_users, :integer
  attribute :total_events, :integer
  attribute :total_points_awarded, :integer
  attribute :total_points_deducted, :integer
  attribute :average_score, :decimal
  attribute :median_score, :integer
  attribute :level_distribution, :jsonb
  attribute :score_buckets, :jsonb
  attribute :top_performers, :jsonb
  attribute :risk_indicators, :jsonb
  attribute :trend_data, :jsonb
  attribute :system_health_metrics, :jsonb

  # Validations
  validates :snapshot_date, presence: true, uniqueness: true
  validates :total_users, :active_users, :total_events, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :recent, ->(days = 7) { where('snapshot_date >= ?', days.days.ago.to_date) }
  scope :by_date, ->(date) { where(snapshot_date: date) }
  scope :latest, -> { order(snapshot_date: :desc).first }

  # Optimized indexes
  # add_index :reputation_analytics_snapshots, :snapshot_date, unique: true
  # add_index :reputation_analytics_snapshots, :total_points_awarded
  # add_index :reputation_analytics_snapshots, :average_score

  # Instance methods for data access
  def level_distribution_data
    return {} unless level_distribution

    level_distribution.transform_keys(&:to_s)
  end

  def score_buckets_data
    return {} unless score_buckets

    score_buckets.transform_keys(&:to_s)
  end

  def top_performers_data
    return [] unless top_performers

    top_performers.map do |performer|
      {
        user_id: performer['user_id'],
        username: performer['username'],
        score: performer['score'],
        level: performer['level']
      }
    end
  end

  def risk_indicators_data
    return {} unless risk_indicators

    risk_indicators.transform_keys(&:to_s)
  end

  def trend_data_points
    return [] unless trend_data

    trend_data.map do |point|
      {
        date: point['date'],
        points_change: point['points_change'],
        running_total: point['running_total']
      }
    end
  end

  def system_health_score
    return 50 unless system_health_metrics

    # Calculate health score based on various metrics
    health_factors = []

    # Error rate factor (lower is better)
    error_rate = system_health_metrics['error_rate'] || 0
    health_factors << (100 - error_rate)

    # Cache hit rate factor (higher is better)
    cache_hit_rate = system_health_metrics['cache_hit_rate'] || 0
    health_factors << cache_hit_rate

    # Database performance factor
    query_time = system_health_metrics['average_query_time_ms'] || 100
    performance_factor = query_time < 50 ? 100 : (query_time < 200 ? 80 : 50)
    health_factors << performance_factor

    # Average of all factors
    health_factors.sum / health_factors.size
  end

  def growth_rate
    return 0 unless trend_data&.size&.> 1

    # Compare first and last data points
    first_point = trend_data.first
    last_point = trend_data.last

    return 0 unless first_point && last_point

    first_score = first_point['running_total'] || 0
    last_score = last_point['running_total'] || 0

    return 0 if first_score.zero?

    ((last_score - first_score).to_f / first_score * 100).round(2)
  end

  def risk_level
    risk_score = risk_indicators_data['overall_risk_score'] || 0

    case risk_score
    when 0..20 then :low
    when 21..50 then :medium
    when 51..80 then :high
    else :critical
    end
  end

  # Class methods for snapshot management
  def self.generate_daily_snapshot(date = Date.current)
    # Generate comprehensive analytics snapshot for the given date
    events = UserReputationEvent.where('DATE(created_at) = ?', date)

    return nil if events.empty?

    # Calculate all metrics
    metrics = calculate_metrics_for_date(date, events)

    # Create or update snapshot
    snapshot = find_or_initialize_by(snapshot_date: date)
    snapshot.update!(metrics)

    snapshot
  end

  def self.generate_snapshots_for_range(start_date, end_date)
    snapshots = []

    (start_date..end_date).each do |date|
      snapshot = generate_daily_snapshot(date)
      snapshots << snapshot if snapshot
    end

    snapshots
  end

  def self.cleanup_old_snapshots(days_to_keep = 90)
    cutoff_date = days_to_keep.days.ago.to_date

    deleted_count = where('snapshot_date < ?', cutoff_date).delete_all

    Rails.logger.info("Cleaned up #{deleted_count} old reputation analytics snapshots")
    deleted_count
  end

  private

  def self.calculate_metrics_for_date(date, events)
    user_scores = events.group(:user_id).sum(:points_change)

    {
      snapshot_date: date,
      total_users: user_scores.size,
      active_users: events.distinct.count(:user_id),
      total_events: events.count,
      total_points_awarded: events.gains.sum(:points_change).to_i,
      total_points_deducted: events.losses.sum(:points_change).abs.to_i,
      average_score: calculate_average_score(user_scores),
      median_score: calculate_median_score(user_scores),
      level_distribution: calculate_level_distribution(user_scores),
      score_buckets: calculate_score_buckets(user_scores),
      top_performers: calculate_top_performers(user_scores),
      risk_indicators: calculate_risk_indicators(events),
      trend_data: calculate_trend_data(date),
      system_health_metrics: calculate_system_health_metrics
    }
  end

  def self.calculate_average_score(user_scores)
    return 0 if user_scores.empty?

    (user_scores.values.sum.to_f / user_scores.size).round(2)
  end

  def self.calculate_median_score(user_scores)
    return 0 if user_scores.empty?

    scores = user_scores.values.sort
    mid = scores.size / 2

    if scores.size.even?
      (scores[mid - 1] + scores[mid]).to_f / 2
    else
      scores[mid]
    end.to_i
  end

  def self.calculate_level_distribution(user_scores)
    distribution = Hash.new(0)

    user_scores.each do |_, score|
      level = ReputationLevel.from_score(score)
      distribution[level] += 1
    end

    distribution.transform_keys(&:to_s)
  end

  def self.calculate_score_buckets(user_scores)
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

  def self.calculate_top_performers(user_scores, limit = 10)
    top_users = user_scores.sort_by { |_, score| -score }.first(limit)

    top_users.map do |user_id, score|
      user = User.find_by(id: user_id)
      next unless user

      {
        user_id: user_id,
        username: user.username,
        score: score,
        level: ReputationLevel.from_score(score).to_s
      }
    end.compact
  end

  def self.calculate_risk_indicators(events)
    recent_losses = events.where('points_change < 0')

    {
      high_frequency_users: calculate_high_frequency_users(events),
      suspicious_patterns: calculate_suspicious_patterns(events),
      rapid_score_changes: calculate_rapid_score_changes(events),
      overall_risk_score: calculate_overall_risk_score(events)
    }
  end

  def self.calculate_trend_data(date)
    # Get trend data for the last 30 days up to the snapshot date
    start_date = [date - 30.days, 30.days.ago.to_date].max

    trend_points = []

    (start_date..date).each do |trend_date|
      day_events = UserReputationEvent.where('DATE(created_at) = ?', trend_date)
      day_change = day_events.sum(:points_change)
      running_total = UserReputationEvent.where('DATE(created_at) <= ?', trend_date)
                                        .sum(:points_change)

      trend_points << {
        date: trend_date.to_s,
        points_change: day_change,
        running_total: running_total
      }
    end

    trend_points
  end

  def self.calculate_system_health_metrics
    {
      average_query_time_ms: 50, # Placeholder - would measure actual query times
      cache_hit_rate: 0.85,
      error_rate: 0.02,
      records_processed: UserReputationEvent.count
    }
  end

  def self.calculate_high_frequency_users(events)
    events.group(:user_id)
          .having('COUNT(*) > 50')
          .count
          .size
  end

  def self.calculate_suspicious_patterns(events)
    # Detect various suspicious patterns
    patterns = []

    # Micro-gaming pattern
    small_gains = events.where('points_change BETWEEN 1 AND 5')
                       .group(:user_id)
                       .having('COUNT(*) > 20')
                       .count

    patterns << { type: :micro_gaming, count: small_gains.size } if small_gains.any?

    patterns
  end

  def self.calculate_rapid_score_changes(events)
    events.where('ABS(points_change) > 100')
          .group(:user_id)
          .count
          .size
  end

  def self.calculate_overall_risk_score(events)
    # Calculate overall risk score (0-100)
    risk_factors = []

    # High frequency factor
    high_freq_ratio = calculate_high_frequency_users(events).to_f / [events.distinct.count(:user_id), 1].max
    risk_factors << (high_freq_ratio * 30)

    # Suspicious patterns factor
    suspicious_count = calculate_suspicious_patterns(events).sum { |p| p[:count] }
    suspicious_ratio = suspicious_count.to_f / [events.count, 1].max
    risk_factors << (suspicious_ratio * 40)

    # Rapid changes factor
    rapid_change_ratio = calculate_rapid_score_changes(events).to_f / [events.distinct.count(:user_id), 1].max
    risk_factors << (rapid_change_ratio * 30)

    risk_score = risk_factors.sum
    [risk_score, 100].min.round(1)
  end
end