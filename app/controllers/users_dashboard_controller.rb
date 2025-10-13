# frozen_string_literal: true

##
# Users Dashboard Controller
# Handles the main user dashboard with personalized widgets and real-time updates
#
class UsersDashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :validate_pagination_params, only: [:activities]

  # Cache dashboard data for 5 minutes to improve performance
  CACHE_EXPIRY = 5.minutes.freeze
  MAX_ACTIVITIES_PER_PAGE = 50
  MAX_RECENT_ITEMS = 10

  ##
  # Main dashboard index action
  # Loads user statistics, recent orders, activity feed, and notifications
  # Implements comprehensive error handling and performance optimizations
  #
  def index
    @user = current_user

    begin
      # Load dashboard statistics with caching
      @statistics = Rails.cache.fetch("user_stats_#{@user.id}", expires_in: CACHE_EXPIRY) do
        load_statistics
      end

      # Load recent orders with optimized queries
      @recent_orders = current_user.orders
                                    .order(created_at: :desc)
                                    .limit(MAX_RECENT_ITEMS)
                                    .includes(:order_items, :seller)

      # Load activity feed with pagination support
      @activities = Rails.cache.fetch("user_activities_#{@user.id}_#{params[:page]}_#{MAX_RECENT_ITEMS}", expires_in: CACHE_EXPIRY) do
        load_activities(page: params[:page]&.to_i || 1, per_page: MAX_RECENT_ITEMS)
      end

      # Load recent notifications with proper error handling
      @notifications = current_user.notifications
                                    .order(created_at: :desc)
                                    .limit(MAX_RECENT_ITEMS)

      # Load gamification data with caching
      @gamification = Rails.cache.fetch("user_gamification_#{@user.id}", expires_in: CACHE_EXPIRY) do
        load_gamification_data
      end

      # Load security status with comprehensive checks
      @security_status = load_security_status

    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error("Dashboard data not found for user #{@user.id}: #{e.message}")
      @statistics = default_statistics
      @recent_orders = []
      @activities = []
      @notifications = []
      @gamification = default_gamification_data
      @security_status = default_security_status
    rescue StandardError => e
      Rails.logger.error("Error loading dashboard for user #{@user.id}: #{e.message}")
      handle_dashboard_error
    end
  end

  ##
  # API endpoint for real-time dashboard stats
  # Returns JSON with updated statistics and proper error handling
  #
  def stats
    begin
      stats_data = Rails.cache.fetch("user_stats_#{current_user.id}", expires_in: CACHE_EXPIRY) do
        load_statistics
      end

      render json: {
        success: true,
        data: stats_data,
        timestamp: Time.current.iso8601
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Error fetching stats for user #{current_user.id}: #{e.message}")
      render json: {
        success: false,
        error: 'Unable to fetch dashboard statistics',
        timestamp: Time.current.iso8601
      }, status: :internal_server_error
    end
  end

  ##
  # API endpoint for activity feed
  # Supports pagination and filtering with comprehensive validation
  #
  def activities
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 10, MAX_ACTIVITIES_PER_PAGE].min

    begin
      activities_data = Rails.cache.fetch("user_activities_#{current_user.id}_#{page}_#{per_page}", expires_in: CACHE_EXPIRY) do
        load_activities(page: page, per_page: per_page)
      end

      render json: {
        success: true,
        data: {
          activities: activities_data,
          pagination: {
            current_page: page,
            per_page: per_page,
            has_more: activities_data.size >= per_page
          }
        },
        timestamp: Time.current.iso8601
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Error fetching activities for user #{current_user.id}: #{e.message}")
      render json: {
        success: false,
        error: 'Unable to fetch activity feed',
        timestamp: Time.current.iso8601
      }, status: :internal_server_error
    end
  end

  ##
  # Clear dashboard cache for current user
  # Useful when user data is updated
  #
  def clear_cache
    begin
      Rails.cache.delete("user_stats_#{current_user.id}")
      Rails.cache.delete_matched("user_activities_#{current_user.id}_*")
      Rails.cache.delete("user_gamification_#{current_user.id}")

      render json: {
        success: true,
        message: 'Dashboard cache cleared successfully',
        timestamp: Time.current.iso8601
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Error clearing cache for user #{current_user.id}: #{e.message}")
      render json: {
        success: false,
        error: 'Unable to clear cache',
        timestamp: Time.current.iso8601
      }, status: :internal_server_error
    end
  end

  private

  ##
  # Load user statistics for dashboard with optimized queries
  # @return [Hash] Statistics data with proper error handling
  #
  def load_statistics
    return default_statistics unless current_user

    order_stats = current_user.orders

    {
      total_orders: order_stats.count,
      active_shipments: order_stats.where(status: [:processing, :shipped]).count,
      completed_orders: order_stats.where(status: :delivered).count,
      wishlist_items: current_user.wishlist_items&.count || 0,
      reward_points: current_user.loyalty_points || 0,
      total_spent: order_stats.where(status: :delivered).sum(:total_amount).to_f,
      average_order_value: calculate_average_order_value(order_stats),
      last_order_date: order_stats.maximum(:created_at)&.to_date,
      favorite_category: current_user.favorite_category
    }
  rescue StandardError => e
    Rails.logger.error("Error loading statistics for user #{current_user.id}: #{e.message}")
    default_statistics
  end

  ##
  # Load user activity feed with optimized queries and proper sorting
  # @param page [Integer] Page number for pagination
  # @param per_page [Integer] Items per page
  # @return [Array<Hash>] Activity items with consistent structure
  #
  def load_activities(page: 1, per_page: 10)
    activities = []

    begin
      # Load recent orders with optimized query
      recent_orders = current_user.orders
                                  .order(created_at: :desc)
                                  .limit(per_page)
                                  .offset((page - 1) * per_page)
                                  .includes(:order_items)

      # Process orders into activities
      recent_orders.each do |order|
        activities << build_order_activity(order)
      end

      # Load recent reviews if available
      if current_user.respond_to?(:reviews)
        recent_reviews = current_user.reviews
                                     .order(created_at: :desc)
                                     .limit(per_page / 2)
                                     .offset((page - 1) * (per_page / 2))

        recent_reviews.each do |review|
          activities << build_review_activity(review)
        end
      end

      # Load recent wishlist activities if available
      if current_user.respond_to?(:wishlist_items)
        recent_wishlist = current_user.wishlist_items
                                      .order(created_at: :desc)
                                      .limit(per_page / 3)
                                      .offset((page - 1) * (per_page / 3))

        recent_wishlist.each do |wishlist_item|
          activities << build_wishlist_activity(wishlist_item)
        end
      end

      # Sort activities by time and return requested page
      sorted_activities = activities.sort_by { |activity| activity[:timestamp] }.reverse
      sorted_activities.first(per_page)

    rescue StandardError => e
      Rails.logger.error("Error loading activities for user #{current_user.id}: #{e.message}")
      []
    end
  end

  ##
  # Load gamification data for the user with comprehensive metrics
  # @return [Hash] Gamification statistics with error handling
  #
  def load_gamification_data
    return default_gamification_data unless current_user

    current_points = current_user.loyalty_points || 0
    current_level = current_user.level || 1

    {
      level: current_level,
      current_points: current_points,
      points_to_next_level: calculate_points_to_next_level(current_level, current_points),
      level_progress_percentage: calculate_level_progress(current_level, current_points),
      achievements_count: current_user.achievements&.count || 0,
      badges: current_user.badges || [],
      recent_achievements: load_recent_achievements,
      streak_data: calculate_streak_data,
      rank_position: calculate_user_rank
    }
  rescue StandardError => e
    Rails.logger.error("Error loading gamification data for user #{current_user.id}: #{e.message}")
    default_gamification_data
  end

  ##
  # Load security status checklist with comprehensive validation
  # @return [Hash] Security status items with detailed information
  #
  def load_security_status
    {
      email_verified: current_user.email_verified? || false,
      two_factor_enabled: current_user.otp_required_for_login || false,
      strong_password: password_strength_check,
      profile_complete: profile_completeness_check,
      last_password_change: current_user.last_password_change_at,
      login_history: load_recent_login_history,
      security_score: calculate_security_score,
      recommendations: generate_security_recommendations
    }
  rescue StandardError => e
    Rails.logger.error("Error loading security status for user #{current_user.id}: #{e.message}")
    default_security_status
  end

  ##
  # Calculate average order value with proper handling of edge cases
  # @param order_stats [ActiveRecord::Relation] Orders relation
  # @return [Float] Average order value or 0.0 if no orders
  #
  def calculate_average_order_value(order_stats)
    delivered_orders = order_stats.where(status: :delivered)
    return 0.0 if delivered_orders.count.zero?

    delivered_orders.average(:total_amount).to_f.round(2)
  end

  ##
  # Calculate points needed for next level with proper validation
  # @param current_level [Integer] Current user level
  # @param current_points [Integer] Current loyalty points
  # @return [Integer] Points needed for next level
  #
  def calculate_points_to_next_level(current_level, current_points)
    next_level_threshold = (current_level + 1) * 1000
    [next_level_threshold - current_points, 0].max
  end

  ##
  # Calculate level progress as percentage
  # @param current_level [Integer] Current user level
  # @param current_points [Integer] Current loyalty points
  # @return [Float] Progress percentage towards next level
  #
  def calculate_level_progress(current_level, current_points)
    current_level_threshold = current_level * 1000
    next_level_threshold = (current_level + 1) * 1000
    points_in_current_level = current_points - current_level_threshold

    return 100.0 if points_in_current_level >= 1000

    ((points_in_current_level.to_f / 1000) * 100).round(1)
  end

  ##
  # Build activity hash for order
  # @param order [Order] Order object
  # @return [Hash] Activity data
  #
  def build_order_activity(order)
    {
      id: "order_#{order.id}",
      type: 'order',
      title: "Order ##{order.id} #{order.status.titleize}",
      description: "Total: $#{order.total_amount&.round(2) || '0.00'}",
      timestamp: order.created_at,
      icon: 'shopping-bag',
      color: order_status_color(order.status),
      metadata: {
        order_id: order.id,
        status: order.status,
        item_count: order.order_items&.count || 0
      }
    }
  end

  ##
  # Build activity hash for review
  # @param review [Review] Review object
  # @return [Hash] Activity data
  #
  def build_review_activity(review)
    {
      id: "review_#{review.id}",
      type: 'review',
      title: 'You left a review',
      description: review.comment&.truncate(50) || 'No comment provided',
      timestamp: review.created_at,
      icon: 'star',
      color: 'yellow',
      metadata: {
        review_id: review.id,
        rating: review.rating,
        product_id: review.product_id
      }
    }
  end

  ##
  # Build activity hash for wishlist item
  # @param wishlist_item [WishlistItem] Wishlist item object
  # @return [Hash] Activity data
  #
  def build_wishlist_activity(wishlist_item)
    {
      id: "wishlist_#{wishlist_item.id}",
      type: 'wishlist',
      title: 'Item added to wishlist',
      description: wishlist_item.product&.name || 'Product unavailable',
      timestamp: wishlist_item.created_at,
      icon: 'heart',
      color: 'pink',
      metadata: {
        wishlist_item_id: wishlist_item.id,
        product_id: wishlist_item.product_id
      }
    }
  end

  ##
  # Load recent achievements for gamification display
  # @return [Array<Hash>] Recent achievements data
  #
  def load_recent_achievements
    return [] unless current_user.respond_to?(:achievements)

    current_user.achievements
                .order(created_at: :desc)
                .limit(3)
                .map do |achievement|
                  {
                    id: achievement.id,
                    name: achievement.name,
                    description: achievement.description,
                    icon: achievement.icon,
                    earned_at: achievement.created_at
                  }
                end
  rescue StandardError => e
    Rails.logger.error("Error loading recent achievements: #{e.message}")
    []
  end

  ##
  # Calculate user streak data for gamification
  # @return [Hash] Streak information
  #
  def calculate_streak_data
    # Placeholder for streak calculation logic
    # In a real implementation, this would analyze user activity patterns
    {
      current_streak: 0,
      longest_streak: 0,
      streak_type: 'daily_login'
    }
  rescue StandardError => e
    Rails.logger.error("Error calculating streak data: #{e.message}")
    { current_streak: 0, longest_streak: 0, streak_type: 'daily_login' }
  end

  ##
  # Calculate user's rank among all users
  # @return [Hash] Rank information
  #
  def calculate_user_rank
    # Placeholder for rank calculation logic
    # In a real implementation, this would compare user points with others
    {
      current_rank: 0,
      total_users: 0,
      percentile: 0.0
    }
  rescue StandardError => e
    Rails.logger.error("Error calculating user rank: #{e.message}")
    { current_rank: 0, total_users: 0, percentile: 0.0 }
  end

  ##
  # Load recent login history for security monitoring
  # @return [Array<Hash>] Recent login events
  #
  def load_recent_login_history
    # Placeholder for login history logic
    # In a real implementation, this would query login audit logs
    []
  rescue StandardError => e
    Rails.logger.error("Error loading login history: #{e.message}")
    []
  end

  ##
  # Calculate overall security score
  # @return [Integer] Security score out of 100
  #
  def calculate_security_score
    score = 0
    score += 25 if current_user.email_verified?
    score += 25 if current_user.otp_required_for_login?
    score += 25 if password_strength_check
    score += 25 if profile_completeness_check
    score
  rescue StandardError => e
    Rails.logger.error("Error calculating security score: #{e.message}")
    0
  end

  ##
  # Generate security recommendations
  # @return [Array<String>] Security improvement suggestions
  #
  def generate_security_recommendations
    recommendations = []

    unless current_user.email_verified?
      recommendations << 'Verify your email address to improve account security'
    end

    unless current_user.otp_required_for_login?
      recommendations << 'Enable two-factor authentication for enhanced protection'
    end

    unless password_strength_check
      recommendations << 'Update your password to meet security requirements'
    end

    unless profile_completeness_check
      recommendations << 'Complete your profile information'
    end

    recommendations
  rescue StandardError => e
    Rails.logger.error("Error generating security recommendations: #{e.message}")
    []
  end

  ##
  # Enhanced password strength check
  # @return [Boolean] True if password meets security criteria
  #
  def password_strength_check
    return false unless current_user.encrypted_password.present?

    # In a production environment, implement proper password strength analysis
    # This is a placeholder for demonstration
    true
  rescue StandardError => e
    Rails.logger.error("Error checking password strength: #{e.message}")
    false
  end

  ##
  # Enhanced profile completeness check
  # @return [Boolean] True if profile meets completeness criteria
  #
  def profile_completeness_check
    required_fields = [:email, :name]
    optional_fields = [:phone, :date_of_birth, :address]

    required_score = required_fields.all? { |field| current_user.send(field).present? } ? 70 : 0
    optional_score = (optional_fields.count { |field| current_user.send(field).present? }.to_f / optional_fields.length * 30).to_i

    (required_score + optional_score) >= 70
  rescue StandardError => e
    Rails.logger.error("Error checking profile completeness: #{e.message}")
    false
  end

  ##
  # Get color for order status with enhanced mapping
  # @param status [String] Order status
  # @return [String] Color name
  #
  def order_status_color(status)
    status_colors = {
      'delivered' => 'green',
      'shipped' => 'blue',
      'processing' => 'yellow',
      'pending' => 'gray',
      'cancelled' => 'red',
      'refunded' => 'red',
      'returned' => 'orange'
    }.freeze

    status_colors[status.to_s] || 'gray'
  end

  ##
  # Validate pagination parameters
  #
  def validate_pagination_params
    if params[:page]&.to_i&.negative? || params[:page]&.to_i&.zero?
      params[:page] = 1
    end

    if params[:per_page]&.to_i&.negative? || params[:per_page]&.to_i&.zero?
      params[:per_page] = 10
    end

    if params[:per_page]&.to_i& > MAX_ACTIVITIES_PER_PAGE
      params[:per_page] = MAX_ACTIVITIES_PER_PAGE
    end
  end

  ##
  # Default statistics when data cannot be loaded
  # @return [Hash] Default statistics structure
  #
  def default_statistics
    {
      total_orders: 0,
      active_shipments: 0,
      completed_orders: 0,
      wishlist_items: 0,
      reward_points: 0,
      total_spent: 0.0,
      average_order_value: 0.0,
      last_order_date: nil,
      favorite_category: nil
    }
  end

  ##
  # Default gamification data when data cannot be loaded
  # @return [Hash] Default gamification structure
  #
  def default_gamification_data
    {
      level: 1,
      current_points: 0,
      points_to_next_level: 1000,
      level_progress_percentage: 0.0,
      achievements_count: 0,
      badges: [],
      recent_achievements: [],
      streak_data: { current_streak: 0, longest_streak: 0, streak_type: 'daily_login' },
      rank_position: { current_rank: 0, total_users: 0, percentile: 0.0 }
    }
  end

  ##
  # Default security status when data cannot be loaded
  # @return [Hash] Default security status structure
  #
  def default_security_status
    {
      email_verified: false,
      two_factor_enabled: false,
      strong_password: false,
      profile_complete: false,
      last_password_change: nil,
      login_history: [],
      security_score: 0,
      recommendations: ['Unable to load security status']
    }
  end

  ##
  # Handle dashboard loading errors gracefully
  #
  def handle_dashboard_error
    @statistics = default_statistics
    @recent_orders = []
    @activities = []
    @notifications = []
    @gamification = default_gamification_data
    @security_status = default_security_status

    # Set flash error for user notification
    flash.now[:error] = 'Some dashboard data could not be loaded. Please refresh the page.'
  end
end