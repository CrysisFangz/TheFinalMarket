# frozen_string_literal: true

##
# Users Dashboard Controller
# Handles the main user dashboard with personalized widgets
#
class UsersDashboardController < ApplicationController
  before_action :authenticate_user!

  ##
  # Main dashboard index action
  # Loads user statistics, recent orders, activity feed, and notifications
  #
  def index
    @user = current_user
    
    # Load dashboard statistics
    @statistics = load_statistics
    
    # Load recent orders (last 5)
    @recent_orders = current_user.orders
                                  .order(created_at: :desc)
                                  .limit(5)
                                  .includes(:order_items)
    
    # Load activity feed (last 10 activities)
    @activities = load_activities
    
    # Load recent notifications
    @notifications = current_user.notifications
                                  .order(created_at: :desc)
                                  .limit(5)
    
    # Gamification data
    @gamification = load_gamification_data
    
    # Security checklist
    @security_status = load_security_status
  end

  ##
  # API endpoint for real-time dashboard stats
  # Returns JSON with updated statistics
  #
  def stats
    render json: {
      total_orders: current_user.orders.count,
      active_shipments: current_user.orders.where(status: [:processing, :shipped]).count,
      wishlist_items: current_user.wishlist_items.count,
      reward_points: current_user.loyalty_points || 0
    }
  end

  ##
  # API endpoint for activity feed
  # Supports pagination and filtering
  #
  def activities
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 10
    
    activities = load_activities(page: page, per_page: per_page)
    
    render json: {
      activities: activities,
      has_more: activities.count >= per_page
    }
  end

  private

  ##
  # Load user statistics for dashboard
  # @return [Hash] Statistics data
  #
  def load_statistics
    {
      total_orders: current_user.orders.count,
      active_shipments: current_user.orders.where(status: [:processing, :shipped]).count,
      wishlist_items: current_user.wishlist_items.count,
      reward_points: current_user.loyalty_points || 0
    }
  end

  ##
  # Load user activity feed
  # @param page [Integer] Page number for pagination
  # @param per_page [Integer] Items per page
  # @return [Array<Hash>] Activity items
  #
  def load_activities(page: 1, per_page: 10)
    activities = []
    
    # Recent orders
    recent_orders = current_user.orders
                                .order(created_at: :desc)
                                .limit(per_page)
                                .offset((page - 1) * per_page)
    
    recent_orders.each do |order|
      activities << {
        type: 'order',
        title: "Order ##{order.id} #{order.status}",
        description: "Total: $#{order.total_amount}",
        time: order.created_at,
        icon: 'shopping-bag',
        color: order_status_color(order.status)
      }
    end
    
    # Recent reviews
    if current_user.respond_to?(:reviews)
      current_user.reviews.order(created_at: :desc).limit(5).each do |review|
        activities << {
          type: 'review',
          title: 'You left a review',
          description: review.comment.truncate(50),
          time: review.created_at,
          icon: 'star',
          color: 'yellow'
        }
      end
    end
    
    # Sort by time and limit
    activities.sort_by { |a| a[:time] }.reverse.take(per_page)
  end

  ##
  # Load gamification data for the user
  # @return [Hash] Gamification statistics
  #
  def load_gamification_data
    {
      level: current_user.level || 1,
      current_points: current_user.loyalty_points || 0,
      points_to_next_level: calculate_points_to_next_level,
      achievements_count: current_user.achievements&.count || 0,
      badges: current_user.badges || []
    }
  end

  ##
  # Load security status checklist
  # @return [Hash] Security status items
  #
  def load_security_status
    {
      email_verified: current_user.email_verified? || false,
      two_factor_enabled: current_user.otp_required_for_login || false,
      strong_password: password_strength_check,
      profile_complete: profile_completeness_check
    }
  end

  ##
  # Calculate points needed for next level
  # @return [Integer] Points needed
  #
  def calculate_points_to_next_level
    current_level = current_user.level || 1
    next_level_threshold = current_level * 1000
    current_points = current_user.loyalty_points || 0
    [next_level_threshold - current_points, 0].max
  end

  ##
  # Check password strength
  # @return [Boolean] True if password is strong
  #
  def password_strength_check
    # Simple check - in production, use proper password strength library
    current_user.encrypted_password.present?
  end

  ##
  # Check profile completeness
  # @return [Boolean] True if profile is complete
  #
  def profile_completeness_check
    required_fields = [:email, :name]
    required_fields.all? { |field| current_user.send(field).present? }
  end

  ##
  # Get color for order status
  # @param status [String] Order status
  # @return [String] Color name
  #
  def order_status_color(status)
    case status.to_s
    when 'delivered'
      'green'
    when 'cancelled', 'refunded'
      'red'
    when 'shipped'
      'blue'
    else
      'gray'
    end
  end

end