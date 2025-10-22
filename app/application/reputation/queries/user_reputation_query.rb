# frozen_string_literal: true

# Query: Retrieve comprehensive reputation information for a user
# Optimized for read performance with caching and efficient database queries
class UserReputationQuery
  include QueryPattern

  attr_reader :user_id, :include_history, :cache_ttl

  def initialize(user_id, include_history: false, cache_ttl: 5.minutes)
    @user_id = user_id
    @include_history = include_history
    @cache_ttl = cache_ttl
  end

  # Execute the query and return reputation data
  def execute
    cache_key = "user_reputation:#{user_id}:#{include_history}"

    Rails.cache.fetch(cache_key, expires_in: cache_ttl) do
      {
        current_score: current_score,
        current_level: current_level,
        level_progress: level_progress,
        permissions: current_permissions,
        statistics: reputation_statistics,
        recent_events: include_history ? recent_events : [],
        achievements: reputation_achievements,
        trends: reputation_trends
      }
    end
  end

  # Get just the current reputation score (fastest query)
  def current_score
    @current_score ||= UserReputationEvent.where(user_id: user_id).sum(:points_change)
  end

  # Get current reputation level
  def current_level
    @current_level ||= ReputationLevel.from_score(current_score).to_s
  end

  # Calculate progress within current level
  def level_progress
    level_obj = ReputationLevel.new(current_level)
    return { percentage: 0, points_to_next: 0 } if level_obj.name == 'exemplary'

    current_min = level_obj.min_score
    current_max = level_obj.max_score
    next_level = ReputationLevel.all_levels[ReputationLevel.all_levels.index(level_obj.name.to_sym) + 1]

    return { percentage: 100, points_to_next: 0 } unless next_level

    next_level_obj = ReputationLevel.new(next_level.to_s)
    progress_range = current_max - current_min
    current_progress = current_score - current_min
    percentage = [(current_progress.to_f / progress_range * 100), 100].min

    {
      percentage: percentage.round(1),
      points_to_next: next_level_obj.min_score - current_score
    }
  end

  # Get current permissions for the user
  def current_permissions
    level_obj = ReputationLevel.new(current_level)
    level_obj.permissions
  end

  # Get comprehensive reputation statistics
  def reputation_statistics
    events = UserReputationEvent.where(user_id: user_id)

    {
      total_events: events.count,
      total_gains: events.gains.sum(:points_change).to_i,
      total_losses: events.losses.sum(:points_change).abs.to_i,
      average_gain: events.gains.average(:points_change)&.round(2) || 0,
      average_loss: events.losses.average(:points_change)&.round(2).abs || 0,
      highest_single_gain: events.gains.maximum(:points_change) || 0,
      highest_single_loss: events.losses.maximum(:points_change).abs || 0,
      streak_current: calculate_current_streak,
      streak_longest: calculate_longest_streak
    }
  end

  # Get recent reputation events
  def recent_events(limit = 10)
    UserReputationEvent.where(user_id: user_id)
                      .order(created_at: :desc)
                      .limit(limit)
                      .map(&:description)
  end

  # Get reputation-based achievements
  def reputation_achievements
    achievements = []

    if current_score >= 1000
      achievements << { name: 'Reputation Master', description: 'Earned 1000+ reputation points', earned_at: achievement_date(1000) }
    end

    if current_score >= 500
      achievements << { name: 'Trusted Contributor', description: 'Earned 500+ reputation points', earned_at: achievement_date(500) }
    end

    if current_score >= 100
      achievements << { name: 'Rising Star', description: 'Earned 100+ reputation points', earned_at: achievement_date(100) }
    end

    if calculate_current_streak >= 7
      achievements << { name: 'Consistency King', description: '7+ days of positive reputation', earned_at: achievement_date_for_streak }
    end

    achievements
  end

  # Get reputation trends over time
  def reputation_trends(days = 30)
    start_date = days.days.ago.to_date

    daily_scores = UserReputationEvent.where(user_id: user_id)
                                     .where('created_at >= ?', start_date)
                                     .group("DATE(created_at)")
                                     .order("DATE(created_at)")
                                     .sum(:points_change)

    # Fill in missing days with zero change
    trends = []
    start_date.upto(Date.current) do |date|
      trends << {
        date: date,
        points_change: daily_scores[date] || 0,
        running_total: calculate_running_total_up_to(date)
      }
    end

    trends
  end

  private

  def calculate_current_streak
    events = UserReputationEvent.where(user_id: user_id)
                               .order(created_at: :desc)
                               .limit(30)

    streak = 0
    events.each do |event|
      break if event.points_change <= 0
      streak += 1
    end

    streak
  end

  def calculate_longest_streak
    events = UserReputationEvent.where(user_id: user_id)
                               .where('points_change > 0')
                               .order(created_at: :desc)

    longest_streak = 0
    current_streak = 0
    last_date = nil

    events.each do |event|
      event_date = event.created_at.to_date

      if last_date.nil? || event_date == last_date.yesterday
        current_streak += 1
      else
        longest_streak = [longest_streak, current_streak].max
        current_streak = 1
      end

      last_date = event_date
    end

    [longest_streak, current_streak].max
  end

  def achievement_date(threshold)
    event = UserReputationEvent.where(user_id: user_id)
                              .where('points_change > 0')
                              .order(:created_at)
                              .detect { |e| running_total_after_event(e) >= threshold }

    event&.created_at
  end

  def achievement_date_for_streak
    # Find when current streak started
    events = UserReputationEvent.where(user_id: user_id)
                               .where('points_change > 0')
                               .order(created_at: :desc)

    streak_start = nil
    events.each_with_index do |event, index|
      if index < calculate_current_streak - 1
        streak_start = event.created_at
      else
        break
      end
    end

    streak_start
  end

  def running_total_after_event(event)
    UserReputationEvent.where(user_id: user_id)
                      .where('created_at <= ?', event.created_at)
                      .sum(:points_change)
  end

  def calculate_running_total_up_to(date)
    UserReputationEvent.where(user_id: user_id)
                      .where('DATE(created_at) <= ?', date)
                      .sum(:points_change)
  end
end