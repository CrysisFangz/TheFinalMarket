class LeaderboardManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'leaderboard_management'
  CACHE_TTL = 10.minutes

  def self.get_top_users(leaderboard, limit = 100)
    cache_key = "#{CACHE_KEY_PREFIX}:top_users:#{leaderboard.id}:#{limit}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          users = LeaderboardRankingService.get_ranked_users(leaderboard, limit)

          EventPublisher.publish('leaderboard.top_users_retrieved', {
            leaderboard_id: leaderboard.id,
            leaderboard_type: leaderboard.leaderboard_type,
            period: leaderboard.period,
            limit: limit,
            users_count: users.count,
            retrieved_at: Time.current
          })

          users
        end
      end
    end
  end

  def self.get_user_rank(leaderboard, user)
    cache_key = "#{CACHE_KEY_PREFIX}:user_rank:#{leaderboard.id}:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          rank = LeaderboardRankingService.get_user_rank(leaderboard, user)

          EventPublisher.publish('leaderboard.user_rank_calculated', {
            leaderboard_id: leaderboard.id,
            user_id: user.id,
            leaderboard_type: leaderboard.leaderboard_type,
            period: leaderboard.period,
            rank: rank,
            calculated_at: Time.current
          })

          rank
        end
      end
    end
  end

  def self.get_user_score(leaderboard, user)
    cache_key = "#{CACHE_KEY_PREFIX}:user_score:#{leaderboard.id}:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          score = LeaderboardRankingService.get_user_score(leaderboard, user)

          EventPublisher.publish('leaderboard.user_score_calculated', {
            leaderboard_id: leaderboard.id,
            user_id: user.id,
            leaderboard_type: leaderboard.leaderboard_type,
            period: leaderboard.period,
            score: score,
            calculated_at: Time.current
          })

          score
        end
      end
    end
  end

  def self.generate_leaderboard_snapshot(leaderboard)
    cache_key = "#{CACHE_KEY_PREFIX}:snapshot:#{leaderboard.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          top_100 = get_top_users(leaderboard, 100)

          snapshot_data = top_100.map.with_index(1) do |user, rank|
            {
              rank: rank,
              user_id: user.id,
              user_name: user.name,
              score: get_user_score(leaderboard, user),
              avatar_url: user.avatar_url
            }
          end

          leaderboard.update!(
            snapshot: snapshot_data,
            last_updated_at: Time.current
          )

          EventPublisher.publish('leaderboard.snapshot_generated', {
            leaderboard_id: leaderboard.id,
            leaderboard_type: leaderboard.leaderboard_type,
            period: leaderboard.period,
            snapshot_size: snapshot_data.count,
            top_score: snapshot_data.first&.[](:score),
            last_updated_at: leaderboard.last_updated_at,
            generated_at: Time.current
          })

          snapshot_data
        end
      end
    end
  end

  def self.refresh_all_leaderboards
    cache_key = "#{CACHE_KEY_PREFIX}:refresh_all"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          leaderboards = Leaderboard.all
          refreshed_count = 0

          leaderboards.find_each do |leaderboard|
            generate_leaderboard_snapshot(leaderboard)
            refreshed_count += 1
          end

          EventPublisher.publish('leaderboard.all_refreshed', {
            total_leaderboards: leaderboards.count,
            refreshed_count: refreshed_count,
            refresh_date: Time.current
          })

          refreshed_count
        end
      end
    end
  end

  def self.get_leaderboard_stats
    cache_key = "#{CACHE_KEY_PREFIX}:stats"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          leaderboards = Leaderboard.all

          stats = {
            total_leaderboards: leaderboards.count,
            leaderboards_by_type: leaderboards.group(:leaderboard_type).count,
            leaderboards_by_period: leaderboards.group(:period).count,
            recently_updated: leaderboards.where('last_updated_at > ?', 1.hour.ago).count,
            stale_leaderboards: leaderboards.where('last_updated_at < ?', 1.day.ago).count,
            average_snapshot_size: leaderboards.where.not(snapshot: nil).average('JSON_LENGTH(snapshot)').to_f
          }

          EventPublisher.publish('leaderboard.stats_generated', {
            total_leaderboards: stats[:total_leaderboards],
            recently_updated_count: stats[:recently_updated],
            stale_count: stats[:stale_leaderboards],
            generated_at: Time.current
          })

          stats
        end
      end
    end
  end

  def self.get_leaderboards_for_user(user)
    cache_key = "#{CACHE_KEY_PREFIX}:user_leaderboards:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          leaderboards = Leaderboard.all

          user_leaderboards = leaderboards.map do |leaderboard|
            rank = get_user_rank(leaderboard, user)
            score = get_user_score(leaderboard, user)

            {
              leaderboard_id: leaderboard.id,
              name: leaderboard.name,
              type: leaderboard.leaderboard_type,
              period: leaderboard.period,
              rank: rank,
              score: score,
              is_participating: rank.present?
            }
          end

          EventPublisher.publish('leaderboard.user_leaderboards_retrieved', {
            user_id: user.id,
            leaderboards_count: user_leaderboards.count,
            participating_count: user_leaderboards.count { |l| l[:is_participating] },
            retrieved_at: Time.current
          })

          user_leaderboards
        end
      end
    end
  end

  def self.get_competitive_analysis(user, leaderboard_type = :points)
    cache_key = "#{CACHE_KEY_PREFIX}:competitive:#{user.id}:#{leaderboard_type}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          leaderboard = Leaderboard.find_by(leaderboard_type: leaderboard_type, period: :all_time)
          return {} unless leaderboard

          user_rank = get_user_rank(leaderboard, user)
          user_score = get_user_score(leaderboard, user)
          top_users = get_top_users(leaderboard, 10)

          analysis = {
            user_rank: user_rank,
            user_score: user_score,
            percentile: calculate_percentile(user_rank, top_users.count),
            points_to_next_rank: calculate_points_to_next_rank(user, top_users),
            rank_trend: calculate_rank_trend(user, leaderboard),
            competitive_advantage: analyze_competitive_advantage(user, top_users),
            improvement_suggestions: generate_improvement_suggestions(user, leaderboard, top_users)
          }

          EventPublisher.publish('leaderboard.competitive_analysis_generated', {
            user_id: user.id,
            leaderboard_type: leaderboard_type,
            user_rank: user_rank,
            percentile: analysis[:percentile],
            generated_at: Time.current
          })

          analysis
        end
      end
    end
  end

  def self.get_leaderboard_history(leaderboard, days = 30)
    cache_key = "#{CACHE_KEY_PREFIX}:history:#{leaderboard.id}:#{days}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          # This would require historical snapshots
          # For now, return current data
          history = {
            current_snapshot: leaderboard.snapshot,
            last_updated: leaderboard.last_updated_at,
            change_indicators: calculate_change_indicators(leaderboard),
            trend_analysis: analyze_trends(leaderboard)
          }

          EventPublisher.publish('leaderboard.history_retrieved', {
            leaderboard_id: leaderboard.id,
            days: days,
            has_history: history[:current_snapshot].present?,
            retrieved_at: Time.current
          })

          history
        end
      end
    end
  end

  private

  def self.calculate_percentile(user_rank, total_users)
    return 0 unless user_rank && total_users > 0

    percentile = ((total_users - user_rank).to_f / total_users) * 100
    [percentile, 100].min
  end

  def self.calculate_points_to_next_rank(user, top_users)
    user_rank = top_users.index { |u| u.id == user.id }
    return 0 unless user_rank && user_rank > 0

    next_user = top_users[user_rank - 1]
    next_score = get_user_score(Leaderboard.find_by(leaderboard_type: :points), next_user)

    [next_score - user.points, 0].max
  end

  def self.calculate_rank_trend(user, leaderboard)
    # This would require historical data
    # For now, return neutral
    'stable'
  end

  def self.analyze_competitive_advantage(user, top_users)
    user_position = top_users.index { |u| u.id == user.id }

    if user_position.nil?
      'not_ranked'
    elsif user_position < 3
      'top_performer'
    elsif user_position < 10
      'competitive'
    else
      'developing'
    end
  end

  def self.generate_improvement_suggestions(user, leaderboard, top_users)
    suggestions = []

    user_rank = top_users.index { |u| u.id == user.id }
    if user_rank.nil? || user_rank > 10
      suggestions << {
        type: 'engagement',
        priority: 'high',
        title: 'Increase Activity',
        description: 'Participate more to improve your ranking'
      }
    end

    if user.points < top_users.first.points * 0.5
      suggestions << {
        type: 'strategy',
        priority: 'medium',
        title: 'Focus on High-Value Actions',
        description: 'Prioritize actions that give more points'
      }
    end

    suggestions
  end

  def self.calculate_change_indicators(leaderboard)
    # This would compare with previous snapshots
    {
      positions_changed: 0,
      new_entries: 0,
      dropped_entries: 0,
      score_changes: {}
    }
  end

  def self.analyze_trends(leaderboard)
    # This would analyze trends over time
    {
      direction: 'stable',
      volatility: 'low',
      consistency: 'high'
    }
  end

  def self.clear_leaderboard_cache(leaderboard_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:top_users:#{leaderboard_id}",
      "#{CACHE_KEY_PREFIX}:snapshot:#{leaderboard_id}",
      "#{CACHE_KEY_PREFIX}:history:#{leaderboard_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end</content>
<content lines="1-200">
class LeaderboardManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'leaderboard_management'
  CACHE_TTL = 10.minutes

  def self.get_top_users(leaderboard, limit = 100)
    cache_key = "#{CACHE_KEY_PREFIX}:top_users:#{leaderboard.id}:#{limit}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          users = LeaderboardRankingService.get_ranked_users(leaderboard, limit)

          EventPublisher.publish('leaderboard.top_users_retrieved', {
            leaderboard_id: leaderboard.id,
            leaderboard_type: leaderboard.leaderboard_type,
            period: leaderboard.period,
            limit: limit,
            users_count: users.count,
            retrieved_at: Time.current
          })

          users
        end
      end
    end
  end

  def self.get_user_rank(leaderboard, user)
    cache_key = "#{CACHE_KEY_PREFIX}:user_rank:#{leaderboard.id}:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          rank = LeaderboardRankingService.get_user_rank(leaderboard, user)

          EventPublisher.publish('leaderboard.user_rank_calculated', {
            leaderboard_id: leaderboard.id,
            user_id: user.id,
            leaderboard_type: leaderboard.leaderboard_type,
            period: leaderboard.period,
            rank: rank,
            calculated_at: Time.current
          })

          rank
        end
      end
    end
  end

  def self.get_user_score(leaderboard, user)
    cache_key = "#{CACHE_KEY_PREFIX}:user_score:#{leaderboard.id}:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          score = LeaderboardRankingService.get_user_score(leaderboard, user)

          EventPublisher.publish('leaderboard.user_score_calculated', {
            leaderboard_id: leaderboard.id,
            user_id: user.id,
            leaderboard_type: leaderboard.leaderboard_type,
            period: leaderboard.period,
            score: score,
            calculated_at: Time.current
          })

          score
        end
      end
    end
  end

  def self.generate_leaderboard_snapshot(leaderboard)
    cache_key = "#{CACHE_KEY_PREFIX}:snapshot:#{leaderboard.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          top_100 = get_top_users(leaderboard, 100)

          snapshot_data = top_100.map.with_index(1) do |user, rank|
            {
              rank: rank,
              user_id: user.id,
              user_name: user.name,
              score: get_user_score(leaderboard, user),
              avatar_url: user.avatar_url
            }
          end

          leaderboard.update!(
            snapshot: snapshot_data,
            last_updated_at: Time.current
          )

          EventPublisher.publish('leaderboard.snapshot_generated', {
            leaderboard_id: leaderboard.id,
            leaderboard_type: leaderboard.leaderboard_type,
            period: leaderboard.period,
            snapshot_size: snapshot_data.count,
            top_score: snapshot_data.first&.[](:score),
            last_updated_at: leaderboard.last_updated_at,
            generated_at: Time.current
          })

          snapshot_data
        end
      end
    end
  end

  def self.refresh_all_leaderboards
    cache_key = "#{CACHE_KEY_PREFIX}:refresh_all"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          leaderboards = Leaderboard.all
          refreshed_count = 0

          leaderboards.find_each do |leaderboard|
            generate_leaderboard_snapshot(leaderboard)
            refreshed_count += 1
          end

          EventPublisher.publish('leaderboard.all_refreshed', {
            total_leaderboards: leaderboards.count,
            refreshed_count: refreshed_count,
            refresh_date: Time.current
          })

          refreshed_count
        end
      end
    end
  end

  def self.get_leaderboard_stats
    cache_key = "#{CACHE_KEY_PREFIX}:stats"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          leaderboards = Leaderboard.all

          stats = {
            total_leaderboards: leaderboards.count,
            leaderboards_by_type: leaderboards.group(:leaderboard_type).count,
            leaderboards_by_period: leaderboards.group(:period).count,
            recently_updated: leaderboards.where('last_updated_at > ?', 1.hour.ago).count,
            stale_leaderboards: leaderboards.where('last_updated_at < ?', 1.day.ago).count,
            average_snapshot_size: leaderboards.where.not(snapshot: nil).average('JSON_LENGTH(snapshot)').to_f
          }

          EventPublisher.publish('leaderboard.stats_generated', {
            total_leaderboards: stats[:total_leaderboards],
            recently_updated_count: stats[:recently_updated],
            stale_count: stats[:stale_leaderboards],
            generated_at: Time.current
          })

          stats
        end
      end
    end
  end

  def self.get_leaderboards_for_user(user)
    cache_key = "#{CACHE_KEY_PREFIX}:user_leaderboards:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          leaderboards = Leaderboard.all

          user_leaderboards = leaderboards.map do |leaderboard|
            rank = get_user_rank(leaderboard, user)
            score = get_user_score(leaderboard, user)

            {
              leaderboard_id: leaderboard.id,
              name: leaderboard.name,
              type: leaderboard.leaderboard_type,
              period: leaderboard.period,
              rank: rank,
              score: score,
              is_participating: rank.present?
            }
          end

          EventPublisher.publish('leaderboard.user_leaderboards_retrieved', {
            user_id: user.id,
            leaderboards_count: user_leaderboards.count,
            participating_count: user_leaderboards.count { |l| l[:is_participating] },
            retrieved_at: Time.current
          })

          user_leaderboards
        end
      end
    end
  end

  def self.get_competitive_analysis(user, leaderboard_type = :points)
    cache_key = "#{CACHE_KEY_PREFIX}:competitive:#{user.id}:#{leaderboard_type}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          leaderboard = Leaderboard.find_by(leaderboard_type: leaderboard_type, period: :all_time)
          return {} unless leaderboard

          user_rank = get_user_rank(leaderboard, user)
          user_score = get_user_score(leaderboard, user)
          top_users = get_top_users(leaderboard, 10)

          analysis = {
            user_rank: user_rank,
            user_score: user_score,
            percentile: calculate_percentile(user_rank, top_users.count),
            points_to_next_rank: calculate_points_to_next_rank(user, top_users),
            rank_trend: calculate_rank_trend(user, leaderboard),
            competitive_advantage: analyze_competitive_advantage(user, top_users),
            improvement_suggestions: generate_improvement_suggestions(user, leaderboard, top_users)
          }

          EventPublisher.publish('leaderboard.competitive_analysis_generated', {
            user_id: user.id,
            leaderboard_type: leaderboard_type,
            user_rank: user_rank,
            percentile: analysis[:percentile],
            generated_at: Time.current
          })

          analysis
        end
      end
    end
  end

  def self.get_leaderboard_history(leaderboard, days = 30)
    cache_key = "#{CACHE_KEY_PREFIX}:history:#{leaderboard.id}:#{days}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_management') do
        with_retry do
          # This would require historical snapshots
          # For now, return current data
          history = {
            current_snapshot: leaderboard.snapshot,
            last_updated: leaderboard.last_updated_at,
            change_indicators: calculate_change_indicators(leaderboard),
            trend_analysis: analyze_trends(leaderboard)
          }

          EventPublisher.publish('leaderboard.history_retrieved', {
            leaderboard_id: leaderboard.id,
            days: days,
            has_history: history[:current_snapshot].present?,
            retrieved_at: Time.current
          })

          history
        end
      end
    end
  end

  private

  def self.calculate_percentile(user_rank, total_users)
    return 0 unless user_rank && total_users > 0

    percentile = ((total_users - user_rank).to_f / total_users) * 100
    [percentile, 100].min
  end

  def self.calculate_points_to_next_rank(user, top_users)
    user_rank = top_users.index { |u| u.id == user.id }
    return 0 unless user_rank && user_rank > 0

    next_user = top_users[user_rank - 1]
    next_score = get_user_score(Leaderboard.find_by(leaderboard_type: :points), next_user)

    [next_score - user.points, 0].max
  end

  def self.calculate_rank_trend(user, leaderboard)
    # This would require historical data
    # For now, return neutral
    'stable'
  end

  def self.analyze_competitive_advantage(user, top_users)
    user_position = top_users.index { |u| u.id == user.id }

    if user_position.nil?
      'not_ranked'
    elsif user_position < 3
      'top_performer'
    elsif user_position < 10
      'competitive'
    else
      'developing'
    end
  end

  def self.generate_improvement_suggestions(user, leaderboard, top_users)
    suggestions = []

    user_rank = top_users.index { |u| u.id == user.id }
    if user_rank.nil? || user_rank > 10
      suggestions << {
        type: 'engagement',
        priority: 'high',
        title: 'Increase Activity',
        description: 'Participate more to improve your ranking'
      }
    end

    if user.points < top_users.first.points * 0.5
      suggestions << {
        type: 'strategy',
        priority: 'medium',
        title: 'Focus on High-Value Actions',
        description: 'Prioritize actions that give more points'
      }
    end

    suggestions
  end

  def self.calculate_change_indicators(leaderboard)
    # This would compare with previous snapshots
    {
      positions_changed: 0,
      new_entries: 0,
      dropped_entries: 0,
      score_changes: {}
    }
  end

  def self.analyze_trends(leaderboard)
    # This would analyze trends over time
    {
      direction: 'stable',
      volatility: 'low',
      consistency: 'high'
    }
  end

  def self.clear_leaderboard_cache(leaderboard_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:top_users:#{leaderboard_id}",
      "#{CACHE_KEY_PREFIX}:snapshot:#{leaderboard_id}",
      "#{CACHE_KEY_PREFIX}:history:#{leaderboard_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end