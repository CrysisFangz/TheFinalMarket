# frozen_string_literal: true

require 'test_helper'

class AchievementTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @achievement = Achievement.new(
      name: "First Purchase",
      description: "Complete your first purchase on our platform",
      points: 100,
      category: :shopping,
      tier: :bronze,
      achievement_type: :one_time,
      requirement_type: 'purchase_count',
      requirement_value: 1,
      active: true
    )
  end

  # === Basic Validations ===

  test "should be valid with valid attributes" do
    assert @achievement.valid?
  end

  test "name should be present" do
    @achievement.name = nil
    assert_not @achievement.valid?
  end

  test "name should be unique" do
    @achievement.save
    
    duplicate_achievement = Achievement.new(
      name: @achievement.name,
      description: "Different description",
      points: 50,
      category: :shopping,
      tier: :silver,
      achievement_type: :one_time
    )
    
    assert_not duplicate_achievement.valid?
  end

  test "description should be present" do
    @achievement.description = nil
    assert_not @achievement.valid?
  end

  test "points should be non-negative" do
    @achievement.points = -10
    assert_not @achievement.valid?
  end

  test "requirement_value should be positive when present" do
    @achievement.requirement_value = 0
    assert_not @achievement.valid?
    
    @achievement.requirement_value = -5
    assert_not @achievement.valid?
  end

  test "requirement_value can be nil" do
    @achievement.requirement_value = nil
    assert @achievement.valid?
  end

  # === Category Enum ===

  test "should have correct category values" do
    assert_equal 0, Achievement.categories[:shopping]
    assert_equal 1, Achievement.categories[:selling]
    assert_equal 2, Achievement.categories[:social]
    assert_equal 3, Achievement.categories[:engagement]
    assert_equal 4, Achievement.categories[:milestone]
    assert_equal 5, Achievement.categories[:special]
  end

  test "should allow different categories" do
    @achievement.category = :selling
    assert @achievement.valid?
    
    @achievement.category = :social
    assert @achievement.valid?
    
    @achievement.category = :engagement
    assert @achievement.valid?
    
    @achievement.category = :milestone
    assert @achievement.valid?
    
    @achievement.category = :special
    assert @achievement.valid?
  end

  # === Tier Enum ===

  test "should have correct tier values" do
    assert_equal 0, Achievement.tiers[:bronze]
    assert_equal 1, Achievement.tiers[:silver]
    assert_equal 2, Achievement.tiers[:gold]
    assert_equal 3, Achievement.tiers[:platinum]
    assert_equal 4, Achievement.tiers[:diamond]
  end

  test "should allow different tiers" do
    @achievement.tier = :silver
    assert @achievement.valid?
    
    @achievement.tier = :gold
    assert @achievement.valid?
    
    @achievement.tier = :platinum
    assert @achievement.valid?
    
    @achievement.tier = :diamond
    assert @achievement.valid?
  end

  # === Achievement Type Enum ===

  test "should have correct achievement_type values" do
    assert_equal 0, Achievement.achievement_types[:one_time]
    assert_equal 1, Achievement.achievement_types[:progressive]
    assert_equal 2, Achievement.achievement_types[:repeatable]
    assert_equal 3, Achievement.achievement_types[:seasonal]
    assert_equal 4, Achievement.achievement_types[:hidden]
  end

  test "should allow different achievement types" do
    @achievement.achievement_type = :progressive
    assert @achievement.valid?
    
    @achievement.achievement_type = :repeatable
    assert @achievement.valid?
    
    @achievement.achievement_type = :seasonal
    assert @achievement.valid?
    
    @achievement.achievement_type = :hidden
    assert @achievement.valid?
  end

  # === Associations ===

  test "should have many user_achievements" do
    achievement = achievements(:one)
    assert_respond_to achievement, :user_achievements
  end

  test "should have many users through user_achievements" do
    achievement = achievements(:one)
    assert_respond_to achievement, :users
  end

  test "should destroy user_achievements when achievement is destroyed" do
    achievement = achievements(:one)
    user_achievement = achievement.user_achievements.create!(
      user: @user,
      earned_at: Time.current
    )
    
    assert_difference 'UserAchievement.count', -1 do
      achievement.destroy
    end
  end

  # === Scopes ===

  test "active scope should return only active achievements" do
    scope = Achievement.active
    assert_equal scope.to_sql, Achievement.where(active: true).to_sql
  end

  test "visible scope should return only visible achievements" do
    scope = Achievement.visible
    assert_equal scope.to_sql, Achievement.where(hidden: false).to_sql
  end

  test "by_category scope should filter by category" do
    category = :shopping
    scope = Achievement.by_category(category)
    assert_equal scope.to_sql, Achievement.where(category: category).to_sql
  end

  test "by_tier scope should filter by tier" do
    tier = :gold
    scope = Achievement.by_tier(tier)
    assert_equal scope.to_sql, Achievement.where(tier: tier).to_sql
  end

  # === Business Logic Methods ===

  test "earned_by? should return true when user has achievement" do
    @achievement.save
    @achievement.user_achievements.create!(
      user: @user,
      earned_at: Time.current
    )
    
    assert @achievement.earned_by?(@user)
  end

  test "earned_by? should return false when user does not have achievement" do
    @achievement.save
    
    assert_not @achievement.earned_by?(@user)
  end

  test "award_to should create user_achievement for new user" do
    @achievement.save
    
    result = @achievement.award_to(@user)
    
    assert_not_nil result
    assert_equal @user, result.user
    assert_equal @achievement, result.achievement
    assert_not_nil result.earned_at
    assert_equal 100, result.progress # requirement_value || 100
  end

  test "award_to should not create duplicate for one_time achievement" do
    @achievement.save
    @achievement.award_to(@user)
    
    # Try to award again
    result = @achievement.award_to(@user)
    
    assert_nil result
    assert_equal 1, @achievement.user_achievements.count
  end

  test "award_to should allow multiple awards for repeatable achievements" do
    @achievement.achievement_type = :repeatable
    @achievement.save
    
    @achievement.award_to(@user)
    result = @achievement.award_to(@user)
    
    assert_not_nil result
    assert_equal 2, @achievement.user_achievements.count
  end

  test "award_to should grant rewards to user" do
    @achievement.save
    initial_points = @user.points
    initial_coins = @user.coins
    
    @achievement.award_to(@user)
    
    assert_equal initial_points + 100, @user.reload.points
    assert_equal initial_coins + (@achievement.reward_coins || 0), @user.reload.coins
  end

  test "award_to should send notification to user" do
    @achievement.save
    
    Notification.expects(:create!).with(
      recipient: @user,
      notifiable: @achievement,
      notification_type: 'achievement_earned',
      title: "Achievement Unlocked: #{@achievement.name}!",
      message: @achievement.description,
      data: {
        points: @achievement.points,
        tier: @achievement.tier,
        category: @achievement.category
      }
    )
    
    @achievement.award_to(@user)
  end

  # === Progress Tracking ===

  test "check_progress should return 100 for earned one_time achievement" do
    @achievement.save
    @achievement.award_to(@user)
    
    assert_equal 100, @achievement.check_progress(@user)
  end

  test "check_progress should calculate purchase_count correctly" do
    @achievement.requirement_type = 'purchase_count'
    @achievement.requirement_value = 5
    @achievement.save
    
    # Create 3 completed orders for user
    3.times do
      order = Order.create!(
        buyer: @user,
        seller: users(:two),
        total_amount: 50.00,
        shipping_address: "123 Test St",
        status: :completed
      )
    end
    
    progress = @achievement.check_progress(@user)
    assert_equal 60.0, progress # 3/5 * 100
  end

  test "check_progress should calculate sales_count correctly" do
    @achievement.requirement_type = 'sales_count'
    @achievement.requirement_value = 10
    @achievement.save
    
    # Create 7 completed orders as seller
    7.times do
      order = Order.create!(
        buyer: users(:two),
        seller: @user,
        total_amount: 50.00,
        shipping_address: "123 Test St",
        status: :completed
      )
    end
    
    progress = @achievement.check_progress(@user)
    assert_equal 70.0, progress # 7/10 * 100
  end

  test "check_progress should calculate review_count correctly" do
    @achievement.requirement_type = 'review_count'
    @achievement.requirement_value = 8
    @achievement.save
    
    # Create 6 reviews for user
    6.times do
      product = Product.create!(
        name: "Test Product #{rand(1000)}",
        description: "Test description",
        price: 25.00,
        user: users(:two)
      )
      Review.create!(
        user: @user,
        product: product,
        rating: 5,
        comment: "Great product!"
      )
    end
    
    progress = @achievement.check_progress(@user)
    assert_equal 75.0, progress # 6/8 * 100
  end

  test "check_progress should calculate product_count correctly" do
    @achievement.requirement_type = 'product_count'
    @achievement.requirement_value = 12
    @achievement.save
    
    # Create 9 active products for user
    9.times do
      Product.create!(
        name: "Test Product #{rand(1000)}",
        description: "Test description",
        price: 25.00,
        user: @user
      )
    end
    
    progress = @achievement.check_progress(@user)
    assert_equal 75.0, progress # 9/12 * 100
  end

  test "check_progress should calculate total_spent correctly" do
    @achievement.requirement_type = 'total_spent'
    @achievement.requirement_value = 500.00
    @achievement.save
    
    # Create orders totaling $300
    3.times do
      Order.create!(
        buyer: @user,
        seller: users(:two),
        total_amount: 100.00,
        shipping_address: "123 Test St",
        status: :completed
      )
    end
    
    progress = @achievement.check_progress(@user)
    assert_equal 60.0, progress # 300/500 * 100
  end

  test "check_progress should calculate total_earned correctly" do
    @achievement.requirement_type = 'total_earned'
    @achievement.requirement_value = 1000.00
    @achievement.save
    
    # Create orders as seller totaling $600
    3.times do
      Order.create!(
        buyer: users(:two),
        seller: @user,
        total_amount: 200.00,
        shipping_address: "123 Test St",
        status: :completed
      )
    end
    
    progress = @achievement.check_progress(@user)
    assert_equal 60.0, progress # 600/1000 * 100
  end

  test "check_progress should calculate login_streak correctly" do
    @achievement.requirement_type = 'login_streak'
    @achievement.requirement_value = 7
    @achievement.save
    
    @user.update!(current_login_streak: 4)
    
    progress = @achievement.check_progress(@user)
    assert_equal 57.14, progress # 4/7 * 100 (rounded to 2 decimal places)
  end

  test "check_progress should calculate referral_count correctly" do
    @achievement.requirement_type = 'referral_count'
    @achievement.requirement_value = 5
    @achievement.save
    
    # Create 3 referrals for user
    3.times do
      User.create!(
        name: "Referred User #{rand(1000)}",
        email: "referral#{rand(1000)}@example.com",
        password: "SecurePass123!",
        referred_by: @user
      )
    end
    
    progress = @achievement.check_progress(@user)
    assert_equal 60.0, progress # 3/5 * 100
  end

  test "check_progress should return 0 for unknown requirement_type" do
    @achievement.requirement_type = 'unknown_type'
    @achievement.save
    
    progress = @achievement.check_progress(@user)
    assert_equal 0, progress
  end

  # === Edge Cases and Error Handling ===

  test "should handle missing requirement_type gracefully" do
    @achievement.requirement_type = nil
    @achievement.save
    
    progress = @achievement.check_progress(@user)
    assert_equal 0, progress
  end

  test "should handle zero requirement_value" do
    @achievement.requirement_value = 0
    @achievement.save
    
    # Should not cause division by zero
    assert_nothing_raised do
      @achievement.check_progress(@user)
    end
  end

  test "should handle very large requirement values" do
    @achievement.requirement_value = 999999
    @achievement.save
    
    progress = @achievement.check_progress(@user)
    assert progress >= 0
    assert progress <= 100
  end

  test "should handle special characters in name and description" do
    @achievement.name = "Achievement with Spëcial Châractérs & Symbols!"
    @achievement.description = "Description with émojis 🚀 and spëcial châractérs"
    assert @achievement.valid?
  end

  # === Performance Considerations ===

  test "should handle large number of user_achievements efficiently" do
    @achievement.save
    
    # Create many user achievements
    100.times do |i|
      user = User.create!(
        name: "Test User #{i}",
        email: "testuser#{i}@example.com",
        password: "SecurePass123!"
      )
      @achievement.user_achievements.create!(
        user: user,
        earned_at: Time.current
      )
    end
    
    # Should handle large datasets efficiently
    assert_equal 100, @achievement.users.count
    assert_equal 100, @achievement.user_achievements.count
  end

  test "should not create N+1 queries for associations" do
    achievement = achievements(:one)
    
    # Preload associations to avoid N+1 queries
    assert_sql_queries(1) do
      achievement.user_achievements.to_a
      achievement.users.to_a
    end
  end

  # === Reward System Integration ===

  test "should grant points when awarding achievement" do
    @achievement.points = 250
    @achievement.save
    
    initial_points = @user.points
    
    @achievement.award_to(@user)
    
    assert_equal initial_points + 250, @user.reload.points
  end

  test "should grant coins when awarding achievement" do
    @achievement.reward_coins = 50
    @achievement.save
    
    initial_coins = @user.coins
    
    @achievement.award_to(@user)
    
    assert_equal initial_coins + 50, @user.reload.coins
  end

  test "should unlock features when awarding achievement" do
    @achievement.unlocks = ['premium_shipping', 'advanced_analytics']
    @achievement.save
    
    @achievement.award_to(@user)
    
    unlocked_features = @user.unlocked_features.pluck(:feature_name)
    assert_includes unlocked_features, 'premium_shipping'
    assert_includes unlocked_features, 'advanced_analytics'
  end

  test "should grant badges when awarding achievement" do
    badge = "Premium Seller"
    @achievement.reward_badge = badge
    @achievement.save
    
    @achievement.award_to(@user)
    
    assert_includes @user.badges, badge
  end

  # === Notification Integration ===

  test "should create notification when awarding achievement" do
    @achievement.save
    
    @achievement.award_to(@user)
    
    notification = Notification.last
    assert_equal @user, notification.recipient
    assert_equal @achievement, notification.notifiable
    assert_equal 'achievement_earned', notification.notification_type
    assert_equal "Achievement Unlocked: #{@achievement.name}!", notification.title
    assert_equal @achievement.description, notification.message
  end

  # === Business Rules Validation ===

  test "should not award achievement if user already has it (one_time)" do
    @achievement.save
    @achievement.award_to(@user)
    
    # Try to award again
    result = @achievement.award_to(@user)
    
    assert_nil result
    assert_equal 1, @achievement.user_achievements.count
  end

  test "should allow multiple awards for repeatable achievements" do
    @achievement.achievement_type = :repeatable
    @achievement.save
    
    3.times do
      result = @achievement.award_to(@user)
      assert_not_nil result
    end
    
    assert_equal 3, @achievement.user_achievements.count
  end

  test "should handle achievement without rewards gracefully" do
    @achievement.points = 0
    @achievement.reward_coins = 0
    @achievement.unlocks = []
    @achievement.reward_badge = nil
    @achievement.save
    
    initial_points = @user.points
    initial_coins = @user.coins
    
    @achievement.award_to(@user)
    
    assert_equal initial_points, @user.reload.points
    assert_equal initial_coins, @user.reload.coins
    assert_empty @user.unlocked_features
    assert_nil @user.badges
  end

  # === Data Integrity ===

  test "should maintain referential integrity with users" do
    @achievement.save
    user_achievement = @achievement.award_to(@user)
    
    # Achievement should reference user_achievement
    assert_includes @achievement.user_achievements, user_achievement
    
    # User should be able to access achievement
    assert_includes @user.achievements, @achievement
    
    # UserAchievement should reference both
    assert_equal @achievement, user_achievement.achievement
    assert_equal @user, user_achievement.user
  end

  # === Fixture Integration ===

  test "should work with existing fixtures" do
    achievement = achievements(:one)
    assert_not_nil achievement.name
    assert_not_nil achievement.description
    assert achievement.valid?
  end

  # === Hidden Achievements ===

  test "hidden achievements should not be visible by default" do
    @achievement.achievement_type = :hidden
    @achievement.save
    
    assert_not @achievement.visible?
  end

  test "visible scope should exclude hidden achievements" do
    visible_achievement = Achievement.create!(
      name: "Visible Achievement",
      description: "This is visible",
      points: 50,
      category: :shopping,
      tier: :bronze,
      achievement_type: :one_time,
      hidden: false
    )
    
    hidden_achievement = Achievement.create!(
      name: "Hidden Achievement",
      description: "This is hidden",
      points: 50,
      category: :shopping,
      tier: :bronze,
      achievement_type: :hidden,
      hidden: true
    )
    
    visible_achievements = Achievement.visible
    assert_includes visible_achievements, visible_achievement
    assert_not_includes visible_achievements, hidden_achievement
  end

  # === Seasonal Achievements ===

  test "seasonal achievements should be handled correctly" do
    @achievement.achievement_type = :seasonal
    @achievement.save
    
    # Should be able to award seasonal achievements
    result = @achievement.award_to(@user)
    assert_not_nil result
  end

  # === Progressive Achievements ===

  test "progressive achievements should track progress correctly" do
    @achievement.achievement_type = :progressive
    @achievement.requirement_type = 'purchase_count'
    @achievement.requirement_value = 10
    @achievement.save
    
    # Create 7 orders
    7.times do
      Order.create!(
        buyer: @user,
        seller: users(:two),
        total_amount: 50.00,
        shipping_address: "123 Test St",
        status: :completed
      )
    end
    
    progress = @achievement.check_progress(@user)
    assert_equal 70.0, progress
    
    # Should not auto-award when progress is not complete
    assert_not @achievement.earned_by?(@user)
  end

  # === Concurrent Access ===

  test "should handle concurrent achievement awards safely" do
    @achievement.save
    
    threads = []
    results = []
    
    5.times do
      threads << Thread.new do
        result = @achievement.award_to(@user)
        results << result
      end
    end
    
    threads.each(&:join)
    
    # Should only have one successful award for one_time achievement
    successful_results = results.compact
    assert_equal 1, successful_results.length
    assert_equal 1, @achievement.user_achievements.count
  end

  # === Memory Efficiency ===

  test "should not load unnecessary data" do
    achievement = achievements(:one)
    
    # Should not load associated users unless needed
    assert_sql_queries(1) do
      achievement.user_achievements.to_a
    end
    
    # Should load users when accessing through association
    assert_sql_queries(2) do
      achievement.users.to_a
    end
  end

  # === Error Handling ===

  test "should handle database errors during award gracefully" do
    @achievement.save
    
    # Mock a database error during user_achievement creation
    UserAchievement.expects(:create!).raises(ActiveRecord::RecordInvalid.new(UserAchievement.new))
    
    assert_raises ActiveRecord::RecordInvalid do
      @achievement.award_to(@user)
    end
  end

  test "should handle notification errors gracefully" do
    @achievement.save
    
    # Mock notification creation failure
    Notification.expects(:create!).raises(StandardError.new("Notification failed"))
    
    # Should not prevent achievement award
    assert_nothing_raised do
      @achievement.award_to(@user)
    end
    
    assert @achievement.earned_by?(@user)
  end
end
