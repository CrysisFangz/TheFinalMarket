# frozen_string_literal: true

# Background Job: Updates reputation leaderboards
# Maintains up-to-date rankings for all leaderboard types
class ReputationLeaderboardUpdateJob
  include Sidekiq::Worker

  sidekiq_options(
    queue: :reputation_leaderboards,
    retry: 2,
    backtrace: true
  )

  # Update specific leaderboard type
  def perform(leaderboard_type, date = nil)
    date ||= Date.current

    Rails.logger.info("Updating #{leaderboard_type} leaderboard for #{date}")

    # Get or create leaderboard
    leaderboard = ReputationLeaderboard.get_leaderboard(leaderboard_type, date)

    # Calculate rankings if stale
    if leaderboard.is_stale?
      calculate_and_update_rankings(leaderboard)
    end

    # Update cache
    update_leaderboard_cache(leaderboard_type, date)

  rescue StandardError => e
    handle_leaderboard_error(leaderboard_type, e)
  end

  # Update all leaderboards
  def self.perform_full_update
    %w[daily weekly monthly all_time].each do |type|
      perform_async(type)
    end
  end

  # Update specific leaderboard type
  def self.perform_type_update(type, date = nil)
    perform_async(type, date)
  end

  private

  def calculate_and_update_rankings(leaderboard)
    start_time = Time.current

    # Calculate rankings for the period
    result = ReputationLeaderboard.calculate_rankings!(
      leaderboard.leaderboard_type,
      leaderboard.period_start,
      leaderboard.period_end
    )

    # Update leaderboard with new rankings
    leaderboard.update!(
      rankings: result[:rankings],
      total_participants: result[:total_participants],
      last_calculated_at: result[:calculated_at]
    )

    duration = Time.current - start_time
    Rails.logger.info("Calculated #{leaderboard.leaderboard_type} rankings in #{duration.round(2)} seconds")
  end

  def update_leaderboard_cache(leaderboard_type, date)
    # Update cached leaderboard data
    cache_key = "leaderboard:#{leaderboard_type}:#{date}"

    leaderboard = ReputationLeaderboard.get_leaderboard(leaderboard_type, date)
    cache_data = {
      rankings: leaderboard.rankings_data,
      total_participants: leaderboard.total_participants,
      last_updated: leaderboard.last_calculated_at
    }

    Rails.cache.write(cache_key, cache_data, expires_in: 15.minutes)
  end

  def handle_leaderboard_error(leaderboard_type, error)
    Rails.logger.error("Leaderboard update failed for #{leaderboard_type}: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))

    # Send error notification
    ErrorNotificationService.notify(
      service: 'ReputationLeaderboardUpdate',
      error: error,
      context: { leaderboard_type: leaderboard_type }
    )
  end
end