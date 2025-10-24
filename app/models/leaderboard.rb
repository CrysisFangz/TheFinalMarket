class Leaderboard < ApplicationRecord
  include CircuitBreaker
  include Retryable

  enum leaderboard_type: {
    points: 0,
    sales: 1,
    purchases: 2,
    reviews: 3,
    social: 4,
    streak: 5,
    weekly: 6,
    monthly: 7,
    all_time: 8
  }

  enum period: {
    daily: 0,
    weekly: 1,
    monthly: 2,
    yearly: 3,
    all_time: 4
  }

  validates :name, presence: true
  validates :leaderboard_type, presence: true
  validates :period, presence: true

  # Caching
  after_create :clear_leaderboard_cache
  after_update :clear_leaderboard_cache
  after_destroy :clear_leaderboard_cache

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event
  
  # Get top users for this leaderboard
  def top_users(limit = 100)
    case leaderboard_type.to_sym
    when :points
      User.order(points: :desc).limit(limit)
    when :sales
      User.joins(:sold_orders)
          .where(orders: { status: :completed })
          .group('users.id')
          .order('SUM(orders.total_amount) DESC')
          .limit(limit)
    when :purchases
      User.joins(:orders)
          .where(orders: { status: :completed })
          .group('users.id')
          .order('COUNT(orders.id) DESC')
          .limit(limit)
    when :reviews
      User.joins(:reviews)
          .group('users.id')
          .order('COUNT(reviews.id) DESC')
          .limit(limit)
    when :social
      User.joins(:followers)
          .group('users.id')
          .order('COUNT(follows.id) DESC')
          .limit(limit)
    when :streak
      User.order(current_login_streak: :desc).limit(limit)
    else
      User.order(points: :desc).limit(limit)
    end
  end
  
  # Get user's rank on this leaderboard
  def user_rank(user)
    users = top_users(1000).pluck(:id)
    rank = users.index(user.id)
    rank ? rank + 1 : nil
  end
  
  # Get user's score for this leaderboard
  def user_score(user)
    case leaderboard_type.to_sym
    when :points
      user.points
    when :sales
      user.sold_orders.completed.sum(:total_amount)
    when :purchases
      user.orders.completed.count
    when :reviews
      user.reviews.count
    when :social
      user.followers.count
    when :streak
      user.current_login_streak
    else
      user.points
    end
  end
  
  # Generate leaderboard snapshot
  def generate_snapshot
    top_100 = top_users(100)
    
    snapshot_data = top_100.map.with_index(1) do |user, rank|
      {
        rank: rank,
        user_id: user.id,
        user_name: user.name,
        score: user_score(user),
        avatar_url: user.avatar_url
      }
    end
    
    update!(
      snapshot: snapshot_data,
      last_updated_at: Time.current
    )
  end
  
  # Refresh leaderboard data
  def self.refresh_all
    find_each do |leaderboard|
      leaderboard.generate_snapshot
    end
  end
end

