class GamificationService
  def initialize(user)
    @user = user
  end
  
  # Track user action and award points/achievements
  def track_action(action_type, metadata = {})
    case action_type
    when :product_view
      track_product_view(metadata)
    when :product_purchase
      track_purchase(metadata)
    when :product_listed
      track_product_listing(metadata)
    when :review_created
      track_review(metadata)
    when :wishlist_add
      track_wishlist_add(metadata)
    when :product_shared
      track_product_share(metadata)
    when :login
      track_login
    when :profile_completed
      track_profile_completion
    when :referral
      track_referral(metadata)
    end
    
    # Check for new achievements
    check_achievements
    
    # Update daily challenges
    update_daily_challenges(action_type, metadata)
  end
  
  # Award points to user
  def award_points(amount, reason = nil)
    @user.increment!(:points, amount)
    
    # Create points transaction record
    create_points_transaction(amount, reason)
    
    # Check for level up
    check_level_up
  end
  
  # Award coins (premium currency)
  def award_coins(amount, reason = nil)
    @user.increment!(:coins, amount)
    
    # Create coins transaction record
    create_coins_transaction(amount, reason)
    
    # Notify user
    notify_coins_awarded(amount, reason)
  end
  
  # Check and award achievements
  def check_achievements
    Achievement.active.find_each do |achievement|
      next if achievement.earned_by?(@user) && achievement.one_time?
      
      progress = achievement.check_progress(@user)
      
      if progress >= 100 && !achievement.earned_by?(@user)
        achievement.award_to(@user)
      elsif achievement.progressive?
        update_achievement_progress(achievement, progress)
      end
    end
  end
  
  # Update daily challenge progress
  def update_daily_challenges(action_type, metadata = {})
    DailyChallenge.today.active.each do |challenge|
      next unless challenge_matches_action?(challenge, action_type)
      
      challenge.update_progress(@user, metadata[:increment] || 1)
    end
  end
  
  # Get user's gamification stats
  def stats
    {
      points: @user.points,
      coins: @user.coins,
      level: @user.level,
      achievements_count: @user.user_achievements.count,
      achievements_total: Achievement.active.count,
      current_streak: @user.current_login_streak,
      longest_streak: @user.longest_login_streak,
      challenges_completed_today: @user.user_daily_challenges.today.completed.count,
      challenges_available_today: DailyChallenge.today.count,
      leaderboard_ranks: get_leaderboard_ranks,
      next_level_points: points_to_next_level,
      level_progress_percentage: level_progress_percentage
    }
  end
  
  # Get user's position on various leaderboards
  def get_leaderboard_ranks
    Leaderboard.all.map do |leaderboard|
      {
        name: leaderboard.name,
        type: leaderboard.leaderboard_type,
        rank: leaderboard.user_rank(@user),
        score: leaderboard.user_score(@user)
      }
    end
  end
  
  # Calculate points needed for next level
  def points_to_next_level
    next_level_requirement = calculate_level_requirement(@user.level + 1)
    [next_level_requirement - @user.points, 0].max
  end
  
  # Calculate level progress percentage
  def level_progress_percentage
    current_level_req = calculate_level_requirement(@user.level)
    next_level_req = calculate_level_requirement(@user.level + 1)
    total_points_for_level = next_level_req - current_level_req
    points_earned_in_level = @user.points - current_level_req
    
    ((points_earned_in_level.to_f / total_points_for_level) * 100).round(2).clamp(0, 100)
  end
  
  private
  
  def track_product_view(metadata)
    award_points(5, "Viewed product: #{metadata[:product_name]}")
    
    # Track for browse challenge
    update_daily_challenges(:browse_products, increment: 1)
  end
  
  def track_purchase(metadata)
    # Award points based on purchase amount
    purchase_points = (metadata[:amount].to_f * 0.1).round
    award_points(purchase_points, "Purchase: #{metadata[:order_id]}")
    
    # Bonus for first purchase
    if @user.orders.completed.count == 1
      award_points(500, "First purchase bonus!")
      check_achievement('first_purchase')
    end
  end
  
  def track_product_listing(metadata)
    award_points(50, "Listed product: #{metadata[:product_name]}")
    
    # Check for listing milestones
    product_count = @user.products.count
    if [1, 10, 50, 100].include?(product_count)
      check_achievement("list_#{product_count}_products")
    end
  end
  
  def track_review(metadata)
    # Award more points for detailed reviews
    points = metadata[:review_length] > 100 ? 100 : 50
    award_points(points, "Review: #{metadata[:product_name]}")
    
    # Bonus for photo reviews
    if metadata[:has_photos]
      award_points(25, "Photo review bonus")
    end
  end
  
  def track_wishlist_add(metadata)
    award_points(10, "Added to wishlist")
  end
  
  def track_product_share(metadata)
    award_points(20, "Shared product")
    award_coins(5, "Social sharing bonus")
  end
  
  def track_login
    # Update login streak
    @user.update_login_streak!
    
    # Award daily login bonus
    award_points(25, "Daily login bonus")
    
    # Bonus for streak milestones
    if @user.current_login_streak % 7 == 0
      award_coins(50, "#{@user.current_login_streak} day streak!")
    end
  end
  
  def track_profile_completion
    completion_percentage = @user.profile_completion_percentage
    
    if completion_percentage == 100
      award_points(200, "Profile completed!")
      award_coins(50, "Profile completion bonus")
    end
  end
  
  def track_referral(metadata)
    award_points(500, "Referred: #{metadata[:referred_user_name]}")
    award_coins(100, "Referral bonus")
  end
  
  def check_level_up
    current_level = @user.level
    new_level = calculate_level_from_points(@user.points)
    
    if new_level > current_level
      @user.update!(level: new_level)
      notify_level_up(new_level)
      grant_level_rewards(new_level)
    end
  end
  
  def calculate_level_from_points(points)
    # Exponential level curve: Level = floor(sqrt(points / 100))
    Math.sqrt(points / 100.0).floor + 1
  end
  
  def calculate_level_requirement(level)
    # Points required for level: (level - 1)^2 * 100
    ((level - 1) ** 2) * 100
  end
  
  def notify_level_up(new_level)
    Notification.create!(
      recipient: @user,
      notifiable: @user,
      notification_type: 'level_up',
      title: "Level Up! You're now Level #{new_level}!",
      message: "Congratulations! You've unlocked new features and rewards.",
      data: {
        new_level: new_level,
        rewards: level_rewards(new_level)
      }
    )
  end
  
  def grant_level_rewards(level)
    rewards = level_rewards(level)
    
    # Award coins
    award_coins(rewards[:coins], "Level #{level} reward")
    
    # Unlock features
    rewards[:unlocks].each do |feature|
      @user.unlocked_features.find_or_create_by!(feature_name: feature)
    end
  end
  
  def level_rewards(level)
    {
      coins: level * 50,
      unlocks: level_unlocks(level)
    }
  end
  
  def level_unlocks(level)
    unlocks = []
    unlocks << 'custom_profile_theme' if level >= 5
    unlocks << 'priority_support' if level >= 10
    unlocks << 'seller_badge' if level >= 15
    unlocks << 'custom_storefront' if level >= 20
    unlocks << 'advanced_analytics' if level >= 25
    unlocks << 'vip_status' if level >= 50
    unlocks
  end
  
  def challenge_matches_action?(challenge, action_type)
    case challenge.challenge_type.to_sym
    when :browse_products
      action_type == :product_view
    when :add_to_wishlist
      action_type == :wishlist_add
    when :make_purchase
      action_type == :product_purchase
    when :leave_review
      action_type == :review_created
    when :list_product
      action_type == :product_listed
    when :share_product
      action_type == :product_shared
    else
      false
    end
  end
  
  def check_achievement(achievement_identifier)
    achievement = Achievement.find_by(identifier: achievement_identifier)
    achievement&.award_to(@user)
  end
  
  def update_achievement_progress(achievement, progress)
    user_achievement = @user.user_achievements.find_or_initialize_by(achievement: achievement)
    user_achievement.update!(progress: progress)
  end
  
  def create_points_transaction(amount, reason)
    # Create transaction record for audit trail
    @user.points_transactions.create!(
      amount: amount,
      reason: reason,
      balance_after: @user.points
    )
  end
  
  def create_coins_transaction(amount, reason)
    @user.coins_transactions.create!(
      amount: amount,
      reason: reason,
      balance_after: @user.coins
    )
  end
  
  def notify_coins_awarded(amount, reason)
    Notification.create!(
      recipient: @user,
      notifiable: @user,
      notification_type: 'coins_awarded',
      title: "You earned #{amount} coins!",
      message: reason,
      data: { amount: amount }
    )
  end
end

