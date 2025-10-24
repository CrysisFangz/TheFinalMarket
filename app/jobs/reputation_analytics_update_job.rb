# frozen_string_literal: true

# Background Job: Updates reputation analytics snapshots
# Runs periodically to maintain up-to-date analytics data
class ReputationAnalyticsUpdateJob
  include Sidekiq::Worker

  sidekiq_options(
    queue: :reputation_analytics,
    retry: 2,
    backtrace: true
  )

  # Update analytics for a specific user
  def perform(user_id = nil, trigger_event_type = nil)
    if user_id
      update_user_analytics(user_id, trigger_event_type)
    else
      update_global_analytics
    end
  end

  # Update analytics for all users (heavy operation)
  def self.perform_global_update
    perform_async
  end

  # Update analytics for specific user
  def self.perform_user_update(user_id, trigger_event_type = nil)
    perform_async(user_id, trigger_event_type)
  end

  private

  def update_user_analytics(user_id, trigger_event_type)
    Rails.logger.info("Updating analytics for user #{user_id}")

    # Update user-specific analytics
    update_user_reputation_summary(user_id)
    update_user_analytics_cache(user_id)

    # Update global analytics if this is a significant event
    if significant_event?(trigger_event_type)
      update_global_analytics_incremental(user_id)
    end

  rescue StandardError => e
    handle_analytics_error("user_#{user_id}", e)
  end

  def update_global_analytics
    Rails.logger.info("Performing global analytics update")

    start_time = Time.current

    # Generate daily snapshot
    snapshot = ReputationAnalyticsSnapshot.generate_daily_snapshot

    if snapshot
      Rails.logger.info("Generated analytics snapshot for #{snapshot.snapshot_date}")
    end

    # Update global caches
    update_global_caches

    # Clean up old snapshots
    cleanup_old_snapshots

    duration = Time.current - start_time
    Rails.logger.info("Global analytics update completed in #{duration.round(2)} seconds")

  rescue StandardError => e
    handle_analytics_error('global', e)
  end

  def update_user_reputation_summary(user_id)
    # Refresh the user's reputation summary
    UserReputationSummary.refresh_for_user(user_id)
  end

  def update_user_analytics_cache(user_id)
    # Update cached analytics data for the user
    cache_key = "user_analytics:#{user_id}"

    Rails.cache.delete(cache_key) # Invalidate old cache

    # Recalculate and cache new analytics
    query = UserReputationQuery.new(user_id, include_history: true)
    analytics_data = query.execute

    Rails.cache.write(cache_key, analytics_data, expires_in: 1.hour)
  end

  def update_global_analytics_incremental(changed_user_id)
    # Incrementally update global analytics when a user changes
    today = Date.current

    # Check if we need a new snapshot
    existing_snapshot = ReputationAnalyticsSnapshot.by_date(today).first

    if existing_snapshot.nil? || existing_snapshot.snapshot_date < today
      # Generate new snapshot
      ReputationAnalyticsSnapshot.generate_daily_snapshot(today)
    else
      # Update existing snapshot incrementally
      update_existing_snapshot(existing_snapshot, changed_user_id)
    end
  end

  def update_existing_snapshot(snapshot, changed_user_id)
    # Update snapshot with changes from specific user
    user_events = UserReputationEvent.where(user_id: changed_user_id)
                                    .where('DATE(created_at) = ?', snapshot.snapshot_date)

    return if user_events.empty?

    # Recalculate affected metrics
    user_scores = { changed_user_id => user_events.sum(:points_change) }

    # Update snapshot with new calculations
    new_metrics = calculate_incremental_metrics(snapshot, user_scores)

    snapshot.update!(new_metrics)
  end

  def update_global_caches
    # Update frequently accessed global caches
    cache_global_leaderboard
    cache_reputation_distribution
    cache_system_health_metrics
  end

  def cache_global_leaderboard
    # Cache top 100 users by reputation
    top_users = UserReputationSummary.top_scorers(100).map do |summary|
      {
        user_id: summary.user_id,
        username: summary.user&.username,
        score: summary.total_score,
        level: summary.reputation_level
      }
    end.compact

    Rails.cache.write('global_leaderboard', top_users, expires_in: 15.minutes)
  end

  def cache_reputation_distribution
    # Cache reputation level distribution
    distribution = UserReputationSummary.distribution_by_level

    Rails.cache.write('reputation_distribution', distribution, expires_in: 1.hour)
  end

  def cache_system_health_metrics
    # Cache system health metrics
    total_events = UserReputationEvent.count
    recent_events = UserReputationEvent.recent(1).count
    average_score = UserReputationSummary.average(:total_score) || 0

    health_metrics = {
      total_events: total_events,
      recent_events: recent_events,
      average_score: average_score,
      last_updated: Time.current
    }

    Rails.cache.write('reputation_health_metrics', health_metrics, expires_in: 5.minutes)
  end

  def cleanup_old_snapshots
    # Clean up snapshots older than 90 days
    ReputationAnalyticsSnapshot.cleanup_old_snapshots(90)
  end

  def calculate_incremental_metrics(snapshot, user_scores)
    # Calculate metrics that need updating due to user changes
    old_total_users = snapshot.total_users
    old_total_points = snapshot.total_points_awarded + snapshot.total_points_deducted

    # Add new user scores to existing data
    new_user_scores = calculate_all_user_scores
    new_user_scores.merge!(user_scores) { |_, old_score, new_score| old_score + new_score }

    {
      total_users: new_user_scores.size,
      average_score: calculate_average_score(new_user_scores),
      level_distribution: calculate_level_distribution(new_user_scores),
      score_buckets: calculate_score_buckets(new_user_scores),
      top_performers: calculate_top_performers(new_user_scores)
    }
  end

  def calculate_all_user_scores
    UserReputationEvent.where('DATE(created_at) = ?', Date.current)
                      .group(:user_id)
                      .sum(:points_change)
  end

  def calculate_average_score(user_scores)
    return 0 if user_scores.empty?

    (user_scores.values.sum.to_f / user_scores.size).round(2)
  end

  def calculate_level_distribution(user_scores)
    distribution = Hash.new(0)

    user_scores.each do |_, score|
      level = ReputationLevel.from_score(score)
      distribution[level] += 1
    end

    distribution.transform_keys(&:to_s)
  end

  def calculate_score_buckets(user_scores)
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

  def calculate_top_performers(user_scores, limit = 10)
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

  def significant_event?(event_type)
    # Determine if an event is significant enough to trigger global analytics update
    significant_events = %w[
      ReputationResetEvent
      ReputationLevelChangedEvent
    ]

    significant_events.include?(event_type)
  end

  def handle_analytics_error(context, error)
    Rails.logger.error("Analytics update failed for #{context}: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))

    # Send error notification
    ErrorNotificationService.notify(
      service: 'ReputationAnalyticsUpdate',
      error: error,
      context: { analytics_context: context }
    )
  end
end