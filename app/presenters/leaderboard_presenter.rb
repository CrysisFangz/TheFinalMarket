class LeaderboardPresenter
  include CircuitBreaker
  include Retryable

  def initialize(leaderboard)
    @leaderboard = leaderboard
  end

  def as_json(options = {})
    cache_key = "leaderboard_presenter:#{@leaderboard.id}:#{@leaderboard.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      with_circuit_breaker('leaderboard_presenter') do
        with_retry do
          {
            id: @leaderboard.id,
            name: @leaderboard.name,
            leaderboard_type: @leaderboard.leaderboard_type,
            period: @leaderboard.period,
            created_at: @leaderboard.created_at,
            updated_at: @leaderboard.updated_at,
            snapshot: snapshot_data,
            top_users: top_users_data,
            stats: stats_data,
            performance: performance_data,
            trends: trends_data,
            configuration: configuration_data
          }
        end
      end
    end
  end

  def to_api_response
    as_json.merge(
      metadata: {
        cache_timestamp: Time.current,
        version: '1.0'
      }
    )
  end

  def to_dashboard_response
    as_json.merge(
      dashboard_data: {
        is_stale: is_stale?,
        refresh_needed: refresh_needed?,
        last_activity: last_activity,
        participation_rate: participation_rate,
        engagement_metrics: engagement_metrics
      }
    )
  end

  private

  def snapshot_data
    Rails.cache.fetch("leaderboard_snapshot:#{@leaderboard.id}", expires_in: 20.minutes) do
      with_circuit_breaker('snapshot_data') do
        with_retry do
          @leaderboard.snapshot || LeaderboardManagementService.generate_leaderboard_snapshot(@leaderboard)
        end
      end
    end
  end

  def top_users_data
    Rails.cache.fetch("leaderboard_top_users:#{@leaderboard.id}", expires_in: 15.minutes) do
      with_circuit_breaker('top_users_data') do
        with_retry do
          top_users = LeaderboardManagementService.get_top_users(@leaderboard, 10)

          top_users.map.with_index(1) do |user, rank|
            {
              rank: rank,
              user_id: user.id,
              user_name: user.name,
              score: LeaderboardManagementService.get_user_score(@leaderboard, user),
              avatar_url: user.avatar_url,
              trend: calculate_user_trend(user),
              badges: get_user_badges(user, rank)
            }
          end
        end
      end
    end
  end

  def stats_data
    Rails.cache.fetch("leaderboard_stats:#{@leaderboard.id}", expires_in: 10.minutes) do
      with_circuit_breaker('stats_data') do
        with_retry do
          LeaderboardManagementService.get_leaderboard_stats
        end
      end
    end
  end

  def performance_data
    Rails.cache.fetch("leaderboard_performance:#{@leaderboard.id}", expires_in: 15.minutes) do
      with_circuit_breaker('performance_data') do
        with_retry do
          {
            total_participants: snapshot_data&.count || 0,
            average_score: calculate_average_score,
            score_distribution: calculate_score_distribution,
            activity_level: calculate_activity_level,
            volatility: calculate_volatility,
            competitiveness: calculate_competitiveness
          }
        end
      end
    end
  end

  def trends_data
    Rails.cache.fetch("leaderboard_trends:#{@leaderboard.id}", expires_in: 20.minutes) do
      with_circuit_breaker('trends_data') do
        with_retry do
          history = LeaderboardManagementService.get_leaderboard_history(@leaderboard)

          {
            direction: history[:trend_analysis][:direction],
            volatility: history[:trend_analysis][:volatility],
            consistency: history[:trend_analysis][:consistency],
            recent_changes: history[:change_indicators],
            growth_rate: calculate_growth_rate,
            stability_score: calculate_stability_score
          }
        end
      end
    end
  end

  def configuration_data
    Rails.cache.fetch("leaderboard_config:#{@leaderboard.id}", expires_in: 30.minutes) do
      with_circuit_breaker('configuration_data') do
        with_retry do
          {
            type: @leaderboard.leaderboard_type,
            period: @leaderboard.period,
            refresh_interval: get_refresh_interval,
            scoring_method: get_scoring_method,
            eligibility_criteria: get_eligibility_criteria,
            display_settings: get_display_settings
          }
        end
      end
    end
  end

  def is_stale?
    @leaderboard.last_updated_at < 1.hour.ago
  end

  def refresh_needed?
    @leaderboard.last_updated_at < 30.minutes.ago
  end

  def last_activity
    snapshot_data&.first&.dig(:updated_at) || @leaderboard.updated_at
  end

  def participation_rate
    total_users = User.count
    participating_users = snapshot_data&.count || 0

    total_users > 0 ? (participating_users.to_f / total_users) * 100 : 0
  end

  def engagement_metrics
    {
      daily_active_users: calculate_daily_active_users,
      weekly_active_users: calculate_weekly_active_users,
      monthly_active_users: calculate_monthly_active_users,
      retention_rate: calculate_retention_rate,
      churn_rate: calculate_churn_rate
    }
  end

  def calculate_average_score
    return 0 unless snapshot_data&.any?

    scores = snapshot_data.map { |entry| entry[:score] }
    scores.sum / scores.count.to_f
  end

  def calculate_score_distribution
    return {} unless snapshot_data&.any?

    scores = snapshot_data.map { |entry| entry[:score] }

    {
      min: scores.min,
      max: scores.max,
      median: calculate_median(scores),
      quartiles: calculate_quartiles(scores),
      standard_deviation: calculate_standard_deviation(scores)
    }
  end

  def calculate_activity_level
    case @leaderboard.leaderboard_type.to_sym
    when :points
      'high'
    when :sales, :purchases
      'medium'
    when :reviews, :social
      'low'
    else
      'medium'
    end
  end

  def calculate_volatility
    # Calculate how much rankings change over time
    'low' # Simplified for now
  end

  def calculate_competitiveness
    return 'low' unless snapshot_data&.any?

    score_range = snapshot_data.first[:score] - snapshot_data.last[:score]
    average_score = calculate_average_score

    if average_score > 0
      competitiveness_ratio = score_range / average_score

      case competitiveness_ratio
      when 0..0.5
        'low'
      when 0.5..1.5
        'medium'
      else
        'high'
      end
    else
      'low'
    end
  end

  def calculate_growth_rate
    # This would require historical data
    0.0
  end

  def calculate_stability_score
    # Calculate how stable the leaderboard is
    85 # Simplified for now
  end

  def calculate_user_trend(user)
    # This would require historical ranking data
    'stable'
  end

  def get_user_badges(user, rank)
    badges = []

    if rank == 1
      badges << { type: 'champion', name: 'Leaderboard Champion', color: 'gold' }
    elsif rank <= 3
      badges << { type: 'top_three', name: 'Top 3', color: 'silver' }
    elsif rank <= 10
      badges << { type: 'top_ten', name: 'Top 10', color: 'bronze' }
    end

    # Add type-specific badges
    case @leaderboard.leaderboard_type.to_sym
    when :points
      if user.points > 10000
        badges << { type: 'high_scorer', name: 'High Scorer', color: 'blue' }
      end
    when :streak
      if user.current_login_streak > 30
        badges << { type: 'dedicated', name: 'Dedicated User', color: 'green' }
      end
    end

    badges
  end

  def calculate_daily_active_users
    # Count users who have activity today
    User.where('last_activity_at >= ?', Date.current.beginning_of_day).count
  end

  def calculate_weekly_active_users
    # Count users who have activity this week
    User.where('last_activity_at >= ?', Date.current.beginning_of_week).count
  end

  def calculate_monthly_active_users
    # Count users who have activity this month
    User.where('last_activity_at >= ?', Date.current.beginning_of_month).count
  end

  def calculate_retention_rate
    # Calculate user retention rate
    75 # Simplified for now
  end

  def calculate_churn_rate
    # Calculate user churn rate
    25 # Simplified for now
  end

  def calculate_median(scores)
    sorted = scores.sort
    mid = scores.count / 2

    if scores.count.odd?
      sorted[mid]
    else
      (sorted[mid - 1] + sorted[mid]) / 2.0
    end
  end

  def calculate_quartiles(scores)
    sorted = scores.sort
    n = sorted.count

    {
      q1: sorted[n / 4],
      q2: calculate_median(scores),
      q3: sorted[(3 * n) / 4]
    }
  end

  def calculate_standard_deviation(scores)
    return 0 if scores.count < 2

    mean = scores.sum / scores.count.to_f
    variance = scores.sum { |score| (score - mean) ** 2 } / scores.count.to_f

    Math.sqrt(variance)
  end

  def get_refresh_interval
    case @leaderboard.period.to_sym
    when :daily
      1.hour
    when :weekly
      6.hours
    when :monthly
      1.day
    else
      3.hours
    end
  end

  def get_scoring_method
    case @leaderboard.leaderboard_type.to_sym
    when :points
      'cumulative_points'
    when :sales
      'total_revenue'
    when :purchases
      'purchase_count'
    when :reviews
      'review_count'
    when :social
      'follower_count'
    when :streak
      'login_streak'
    else
      'points'
    end
  end

  def get_eligibility_criteria
    {
      minimum_activity: get_minimum_activity_requirement,
      account_age_days: 7,
      verification_required: requires_verification?,
      region_restrictions: get_region_restrictions
    }
  end

  def get_display_settings
    {
      show_avatars: true,
      show_scores: true,
      show_ranks: true,
      show_trends: true,
      max_entries: 100,
      public_visibility: true
    }
  end

  def get_minimum_activity_requirement
    case @leaderboard.leaderboard_type.to_sym
    when :points
      10
    when :sales
      1
    when :purchases
      1
    when :reviews
      1
    when :social
      5
    else
      1
    end
  end

  def requires_verification?
    [:sales, :purchases].include?(@leaderboard.leaderboard_type.to_sym)
  end

  def get_region_restrictions
    # This would depend on business rules
    []
  end
end