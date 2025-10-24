class LeaderboardRankingService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'leaderboard_ranking'
  CACHE_TTL = 15.minutes

  def self.get_ranked_users(leaderboard, limit = 100)
    cache_key = "#{CACHE_KEY_PREFIX}:ranked_users:#{leaderboard.id}:#{limit}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_ranking') do
        with_retry do
          users = case leaderboard.leaderboard_type.to_sym
                  when :points
                    rank_by_points(limit)
                  when :sales
                    rank_by_sales(leaderboard.period, limit)
                  when :purchases
                    rank_by_purchases(leaderboard.period, limit)
                  when :reviews
                    rank_by_reviews(leaderboard.period, limit)
                  when :social
                    rank_by_social(leaderboard.period, limit)
                  when :streak
                    rank_by_streak(limit)
                  when :weekly
                    rank_by_weekly_activity(limit)
                  when :monthly
                    rank_by_monthly_activity(limit)
                  when :all_time
                    rank_by_all_time(leaderboard.leaderboard_type, limit)
                  else
                    rank_by_points(limit)
                  end

          EventPublisher.publish('leaderboard.users_ranked', {
            leaderboard_id: leaderboard.id,
            leaderboard_type: leaderboard.leaderboard_type,
            period: leaderboard.period,
            limit: limit,
            ranked_count: users.count,
            top_score: users.first&.score,
            ranked_at: Time.current
          })

          users
        end
      end
    end
  end

  def self.get_user_rank(leaderboard, user)
    cache_key = "#{CACHE_KEY_PREFIX}:user_rank:#{leaderboard.id}:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_ranking') do
        with_retry do
          all_users = get_ranked_users(leaderboard, 1000)
          user_entry = all_users.find { |u| u.id == user.id }

          if user_entry
            all_users.index(user_entry) + 1
          else
            nil
          end
        end
      end
    end
  end

  def self.get_user_score(leaderboard, user)
    cache_key = "#{CACHE_KEY_PREFIX}:user_score:#{leaderboard.id}:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_ranking') do
        with_retry do
          score = case leaderboard.leaderboard_type.to_sym
                  when :points
                    user.points
                  when :sales
                    calculate_sales_score(user, leaderboard.period)
                  when :purchases
                    calculate_purchases_score(user, leaderboard.period)
                  when :reviews
                    calculate_reviews_score(user, leaderboard.period)
                  when :social
                    calculate_social_score(user, leaderboard.period)
                  when :streak
                    user.current_login_streak
                  when :weekly
                    calculate_weekly_score(user)
                  when :monthly
                    calculate_monthly_score(user)
                  when :all_time
                    calculate_all_time_score(user, leaderboard.leaderboard_type)
                  else
                    user.points
                  end

          score
        end
      end
    end
  end

  def self.get_leaderboard_position_changes(leaderboard, previous_snapshot)
    cache_key = "#{CACHE_KEY_PREFIX}:position_changes:#{leaderboard.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('leaderboard_ranking') do
        with_retry do
          current_users = get_ranked_users(leaderboard, 100)

          changes = {
            positions_gained: [],
            positions_lost: [],
            new_entries: [],
            dropped_out: []
          }

          if previous_snapshot.present?
            previous_user_ids = previous_snapshot.map { |entry| entry['user_id'] }
            current_user_ids = current_users.map(&:id)

            # Find new entries
            changes[:new_entries] = current_user_ids - previous_user_ids

            # Find dropped out users
            changes[:dropped_out] = previous_user_ids - current_user_ids

            # Find position changes
            current_users.each_with_index do |user, current_index|
              previous_index = previous_user_ids.index(user.id)
              if previous_index
                position_change = previous_index - current_index
                if position_change > 0
                  changes[:positions_gained] << { user_id: user.id, positions: position_change }
                elsif position_change < 0
                  changes[:positions_lost] << { user_id: user.id, positions: position_change.abs }
                end
              end
            end
          end

          EventPublisher.publish('leaderboard.position_changes_calculated', {
            leaderboard_id: leaderboard.id,
            new_entries_count: changes[:new_entries].count,
            dropped_out_count: changes[:dropped_out].count,
            positions_gained_count: changes[:positions_gained].count,
            positions_lost_count: changes[:positions_lost].count,
            calculated_at: Time.current
          })

          changes
        end
      end
    end
  end

  private

  def self.rank_by_points(limit)
    User.order(points: :desc).limit(limit).map do |user|
      OpenStruct.new(
        id: user.id,
        name: user.name,
        score: user.points,
        avatar_url: user.avatar_url
      )
    end
  end

  def self.rank_by_sales(period, limit)
    period_filter = get_period_filter(period)

    User.joins(:orders)
        .where(orders: { status: :completed }.merge(period_filter))
        .group('users.id')
        .order('SUM(orders.total_amount) DESC')
        .limit(limit)
        .map do |user|
          score = user.orders.where(period_filter).completed.sum(:total_amount)
          OpenStruct.new(
            id: user.id,
            name: user.name,
            score: score,
            avatar_url: user.avatar_url
          )
        end
  end

  def self.rank_by_purchases(period, limit)
    period_filter = get_period_filter(period)

    User.joins(:orders)
        .where(orders: { status: :completed }.merge(period_filter))
        .group('users.id')
        .order('COUNT(orders.id) DESC')
        .limit(limit)
        .map do |user|
          score = user.orders.where(period_filter).completed.count
          OpenStruct.new(
            id: user.id,
            name: user.name,
            score: score,
            avatar_url: user.avatar_url
          )
        end
  end

  def self.rank_by_reviews(period, limit)
    period_filter = get_period_filter(period)

    User.joins(:reviews)
        .where(reviews: period_filter)
        .group('users.id')
        .order('COUNT(reviews.id) DESC')
        .limit(limit)
        .map do |user|
          score = user.reviews.where(period_filter).count
          OpenStruct.new(
            id: user.id,
            name: user.name,
            score: score,
            avatar_url: user.avatar_url
          )
        end
  end

  def self.rank_by_social(period, limit)
    period_filter = get_period_filter(period)

    User.joins(:followers)
        .where(follows: period_filter)
        .group('users.id')
        .order('COUNT(follows.id) DESC')
        .limit(limit)
        .map do |user|
          score = user.followers.where(period_filter).count
          OpenStruct.new(
            id: user.id,
            name: user.name,
            score: score,
            avatar_url: user.avatar_url
          )
        end
  end

  def self.rank_by_streak(limit)
    User.order(current_login_streak: :desc).limit(limit).map do |user|
      OpenStruct.new(
        id: user.id,
        name: user.name,
        score: user.current_login_streak,
        avatar_url: user.avatar_url
      )
    end
  end

  def self.rank_by_weekly_activity(limit)
    week_start = Date.current.beginning_of_week

    User.joins(:user_activity_events)
        .where('user_activity_events.created_at >= ?', week_start)
        .group('users.id')
        .order('COUNT(user_activity_events.id) DESC')
        .limit(limit)
        .map do |user|
          score = user.user_activity_events.where('created_at >= ?', week_start).count
          OpenStruct.new(
            id: user.id,
            name: user.name,
            score: score,
            avatar_url: user.avatar_url
          )
        end
  end

  def self.rank_by_monthly_activity(limit)
    month_start = Date.current.beginning_of_month

    User.joins(:user_activity_events)
        .where('user_activity_events.created_at >= ?', month_start)
        .group('users.id')
        .order('COUNT(user_activity_events.id) DESC')
        .limit(limit)
        .map do |user|
          score = user.user_activity_events.where('created_at >= ?', month_start).count
          OpenStruct.new(
            id: user.id,
            name: user.name,
            score: score,
            avatar_url: user.avatar_url
          )
        end
  end

  def self.rank_by_all_time(leaderboard_type, limit)
    case leaderboard_type.to_sym
    when :points
      rank_by_points(limit)
    when :sales
      rank_by_sales(:all_time, limit)
    when :purchases
      rank_by_purchases(:all_time, limit)
    when :reviews
      rank_by_reviews(:all_time, limit)
    when :social
      rank_by_social(:all_time, limit)
    else
      rank_by_points(limit)
    end
  end

  def self.calculate_sales_score(user, period)
    period_filter = get_period_filter(period)
    user.orders.where(period_filter).completed.sum(:total_amount)
  end

  def self.calculate_purchases_score(user, period)
    period_filter = get_period_filter(period)
    user.orders.where(period_filter).completed.count
  end

  def self.calculate_reviews_score(user, period)
    period_filter = get_period_filter(period)
    user.reviews.where(period_filter).count
  end

  def self.calculate_social_score(user, period)
    period_filter = get_period_filter(period)
    user.followers.where(period_filter).count
  end

  def self.calculate_weekly_score(user)
    week_start = Date.current.beginning_of_week
    user.user_activity_events.where('created_at >= ?', week_start).count
  end

  def self.calculate_monthly_score(user)
    month_start = Date.current.beginning_of_month
    user.user_activity_events.where('created_at >= ?', month_start).count
  end

  def self.calculate_all_time_score(user, leaderboard_type)
    case leaderboard_type.to_sym
    when :points
      user.points
    when :sales
      user.orders.completed.sum(:total_amount)
    when :purchases
      user.orders.completed.count
    when :reviews
      user.reviews.count
    when :social
      user.followers.count
    else
      user.points
    end
  end

  def self.get_period_filter(period)
    case period.to_sym
    when :daily
      { created_at: Date.current.all_day }
    when :weekly
      { created_at: Date.current.all_week }
    when :monthly
      { created_at: Date.current.all_month }
    when :yearly
      { created_at: Date.current.all_year }
    else
      {}
    end
  end

  def self.clear_ranking_cache(leaderboard_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:ranked_users:#{leaderboard_id}",
      "#{CACHE_KEY_PREFIX}:user_rank:#{leaderboard_id}",
      "#{CACHE_KEY_PREFIX}:user_score:#{leaderboard_id}",
      "#{CACHE_KEY_PREFIX}:position_changes:#{leaderboard_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end