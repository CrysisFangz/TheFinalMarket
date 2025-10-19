# frozen_string_literal: true

# DashboardPresenter - High-performance data aggregation service for user dashboard
# Implements caching, eager loading, and optimized queries for dashboard widgets
class DashboardPresenter
  include Rails.application.routes.url_helpers

  # Cache dashboard data for 5 minutes to reduce database load
  CACHE_EXPIRY = 5.minutes

  def initialize(user)
    @user = user
    @cache_key = "dashboard_data_v3_#{user.id}_#{user.updated_at.to_i}"
  end

  def dashboard_data
    Rails.cache.fetch(@cache_key, expires_in: CACHE_EXPIRY) do
      aggregate_dashboard_data
    end
  end

  def stats_overview
    @stats_overview ||= begin
      orders = @user.orders.includes(:order_items)

      {
        total_orders: orders.count,
        active_shipments: orders.where(status: [:processing, :shipped]).count,
        wishlist_items: @user.wishlist_items.count,
        reward_points: @user.points || 0,
        level: @user.level || 1,
        orders_trend: calculate_orders_trend,
        unread_notifications: @user.unread_notifications_count
      }
    end
  end

  def recent_orders
    @recent_orders ||= @user.orders
                           .includes(:order_items)
                           .order(created_at: :desc)
                           .limit(3)
                           .map { |order| present_order(order) }
  end

  def recent_activities
    @recent_activities ||= begin
      activities = []

      # Recent orders
      @user.orders.order(created_at: :desc).limit(3).each do |order|
        activities << {
          id: "order_#{order.id}",
          type: 'order',
          title: 'Order placed successfully',
          meta: "Order ##{order.id} • #{order.created_at.strftime('%b %d, %Y')}",
          icon: 'shopping-cart',
          timestamp: order.created_at
        }
      end

      # Recent reviews
      @user.reviews.order(created_at: :desc).limit(2).each do |review|
        activities << {
          id: "review_#{review.id}",
          type: 'review',
          title: 'Review submitted',
          meta: "#{review.product.title.truncate(30)} • #{time_ago(review.created_at)}",
          icon: 'star',
          timestamp: review.created_at
        }
      end

      # Recent wishlist additions
      @user.wishlist_items.order(created_at: :desc).limit(2).each do |item|
        activities << {
          id: "wishlist_#{item.id}",
          type: 'wishlist',
          title: 'Item added to wishlist',
          meta: "#{item.product.title.truncate(30)} • #{time_ago(item.created_at)}",
          icon: 'heart',
          timestamp: item.created_at
        }
      end

      # Sort by timestamp and limit to 5 most recent
      activities
        .sort_by { |activity| activity[:timestamp] }
        .reverse
        .first(5)
    end
  end

  def security_status
    @security_status ||= {
      email_verified: @user.email_verified?,
      two_factor_enabled: @user.two_factor_enabled?,
      strong_password: true, # Assume password is strong if account exists
      last_login: @user.last_sign_in_at,
      login_streak: calculate_login_streak
    }
  end

  def quick_actions
    @quick_actions ||= [
      {
        title: 'Shop Now',
        path: root_path,
        icon: 'shopping-bag',
        badge: nil
      },
      {
        title: 'My Orders',
        path: orders_path,
        icon: 'clipboard-list',
        badge: nil
      },
      {
        title: 'Wishlist',
        path: wishlist_path,
        icon: 'heart',
        badge: nil
      },
      {
        title: 'Messages',
        path: conversations_path,
        icon: 'chat-bubble-left-right',
        badge: nil
      },
      {
        title: 'Notifications',
        path: notifications_index_path,
        icon: 'bell',
        badge: stats_overview[:unread_notifications] if stats_overview[:unread_notifications] > 0
      },
      {
        title: 'Settings',
        path: edit_user_path(@user),
        icon: 'cog-6-tooth',
        badge: nil
      }
    ]
  end

  def gamification_data
    return nil unless @user.points.present? && @user.points > 0

    @gamification_data ||= begin
      points_for_next_level = ((@user.level || 1) * 1000)
      current_level_points = ((@user.level || 1) - 1) * 1000
      progress_percentage = [((@user.points - current_level_points) / 10.0), 100].min

      {
        level: @user.level || 1,
        points: @user.points,
        points_for_next_level: points_for_next_level,
        progress_percentage: progress_percentage,
        achievements: [
          { icon: '🏆', unlocked: true },
          { icon: '⭐', unlocked: true },
          { icon: '💎', unlocked: (@user.points > 2000) },
          { icon: '🔒', unlocked: false }
        ]
      }
    end
  end

  private

  def aggregate_dashboard_data
    {
      stats_overview: stats_overview,
      recent_orders: recent_orders,
      recent_activities: recent_activities,
      security_status: security_status,
      quick_actions: quick_actions,
      gamification_data: gamification_data,
      last_updated: Time.current
    }
  end

  def present_order(order)
    {
      id: order.id,
      status: order.status,
      status_title: order.status.titleize,
      item_count: order.order_items.sum(:quantity),
      created_at: order.created_at,
      formatted_date: order.created_at.strftime('%b %d, %Y'),
      total_items: order.order_items.sum(:quantity)
    }
  end

  def calculate_orders_trend
    # Calculate trend for current month vs previous month
    current_month = @user.orders.where(created_at: 1.month.ago..Time.current).count
    previous_month = @user.orders.where(created_at: 2.months.ago..1.month.ago).count

    return 0 if previous_month.zero?

    ((current_month - previous_month) / previous_month.to_f * 100).round
  end

  def calculate_login_streak
    return 0 unless @user.last_sign_in_at

    # Simple streak calculation based on consecutive days
    days_since_login = (Time.current.to_date - @user.last_sign_in_at.to_date).to_i
    days_since_login <= 1 ? 1 : 0
  end

  def time_ago(time)
    return 'Unknown' unless time

    time_ago_in_words(time)
  end
end