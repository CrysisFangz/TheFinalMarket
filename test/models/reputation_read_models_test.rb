# frozen_string_literal: true

require 'test_helper'

class ReputationReadModelsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user_id = @user.id
  end

  # Test UserReputationSummary
  test 'creates and refreshes reputation summary' do
    # Create some reputation events
    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 50,
      reason: 'test gain'
    )

    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_lost,
      points_change: -10,
      reason: 'test loss',
      violation_type: 'spam'
    )

    # Refresh summary
    summary = UserReputationSummary.refresh_for_user(@user_id)

    assert_equal 40, summary.total_score # 50 - 10
    assert_equal 2, summary.events_count
    assert_equal 'regular', summary.reputation_level
  end

  test 'calculates level progress correctly' do
    summary = UserReputationSummary.refresh_for_user(@user_id)

    progress = summary.level_progress

    assert_includes progress.keys, :percentage
    assert_includes progress.keys, :points_to_next
    assert progress[:percentage] >= 0
    assert progress[:percentage] <= 100
  end

  test 'calculates reputation velocity correctly' do
    # Create events over time
    5.times do |i|
      UserReputationEvent.create!(
        user_id: @user_id,
        event_type: :reputation_gained,
        points_change: 10,
        reason: 'velocity test',
        created_at: (i + 1).days.ago
      )
    end

    summary = UserReputationSummary.refresh_for_user(@user_id)
    velocity = summary.reputation_velocity(5)

    assert_equal 10.0, velocity # 50 points / 5 days = 10 per day
  end

  test 'calculates consistency score correctly' do
    # Create consistent daily gains
    7.times do |i|
      UserReputationEvent.create!(
        user_id: @user_id,
        event_type: :reputation_gained,
        points_change: 10,
        reason: 'consistency test',
        created_at: (i + 1).days.ago
      )
    end

    summary = UserReputationSummary.refresh_for_user(@user_id)
    consistency = summary.consistency_score(7)

    assert consistency > 80 # Should be high for consistent gains
  end

  test 'calculates risk score correctly' do
    # Create some losses to increase risk
    3.times do |i|
      UserReputationEvent.create!(
        user_id: @user_id,
        event_type: :reputation_lost,
        points_change: -20,
        reason: "risk test #{i}",
        violation_type: 'spam',
        created_at: (i + 1).days.ago
      )
    end

    summary = UserReputationSummary.refresh_for_user(@user_id)
    risk_score = summary.risk_score

    assert risk_score > 0
    assert risk_score <= 100
  end

  test 'determines achievements correctly' do
    # Set high reputation for achievements
    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 1000,
      reason: 'achievement test'
    )

    summary = UserReputationSummary.refresh_for_user(@user_id)
    achievements = summary.achievements

    assert_includes achievements, 'Reputation Master'
    assert_includes achievements, 'Trusted Contributor'
  end

  test 'checks permissions correctly' do
    summary = UserReputationSummary.refresh_for_user(@user_id)

    # Regular level should allow basic permissions
    assert summary.can_post_content?
    assert_not summary.can_moderate?

    # Set to exemplary level
    summary.update!(reputation_level: 'exemplary')

    assert summary.can_post_content?
    assert summary.can_moderate?
    assert summary.can_access_premium_features?
  end

  # Test ReputationAnalyticsSnapshot
  test 'generates daily analytics snapshot' do
    # Create test data for today
    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 50,
      reason: 'analytics test',
      created_at: Time.current
    )

    snapshot = ReputationAnalyticsSnapshot.generate_daily_snapshot(Date.current)

    assert snapshot.present?
    assert_equal Date.current, snapshot.snapshot_date
    assert_equal 1, snapshot.total_users
    assert_equal 50, snapshot.total_points_awarded
  end

  test 'calculates analytics metrics correctly' do
    # Create diverse test data
    user2 = users(:two)

    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 100,
      reason: 'test',
      created_at: Time.current
    )

    UserReputationEvent.create!(
      user_id: user2.id,
      event_type: :reputation_lost,
      points_change: -20,
      reason: 'test',
      violation_type: 'spam',
      created_at: Time.current
    )

    snapshot = ReputationAnalyticsSnapshot.generate_daily_snapshot(Date.current)

    assert_equal 2, snapshot.total_users
    assert_equal 100, snapshot.total_points_awarded
    assert_equal 20, snapshot.total_points_deducted
    assert_equal 40.0, snapshot.average_score # (100 - 20) / 2
  end

  test 'provides analytics data access methods' do
    snapshot = ReputationAnalyticsSnapshot.generate_daily_snapshot(Date.current)

    assert_respond_to snapshot, :level_distribution_data
    assert_respond_to snapshot, :score_buckets_data
    assert_respond_to snapshot, :top_performers_data
    assert_respond_to snapshot, :risk_indicators_data
    assert_respond_to snapshot, :trend_data_points
  end

  test 'calculates system health score' do
    snapshot = ReputationAnalyticsSnapshot.generate_daily_snapshot(Date.current)

    health_score = snapshot.system_health_score

    assert health_score >= 0
    assert health_score <= 100
  end

  test 'calculates growth rate correctly' do
    # Create snapshot with trend data
    snapshot = ReputationAnalyticsSnapshot.generate_daily_snapshot(Date.current)

    # Mock trend data for testing
    snapshot.update!(
      trend_data: [
        { 'date' => 7.days.ago.to_s, 'running_total' => 100 },
        { 'date' => Date.current.to_s, 'running_total' => 150 }
      ]
    )

    growth_rate = snapshot.growth_rate

    assert_equal 50.0, growth_rate # 50% growth
  end

  test 'determines risk level correctly' do
    snapshot = ReputationAnalyticsSnapshot.generate_daily_snapshot(Date.current)

    # Mock low risk indicators
    snapshot.update!(
      risk_indicators: {
        'overall_risk_score' => 15
      }
    )

    assert_equal :low, snapshot.risk_level

    # Mock high risk indicators
    snapshot.update!(
      risk_indicators: {
        'overall_risk_score' => 75
      }
    )

    assert_equal :high, snapshot.risk_level
  end

  # Test ReputationLeaderboard
  test 'creates and calculates leaderboard' do
    # Create test users with different scores
    user2 = users(:two)

    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 100,
      reason: 'leaderboard test'
    )

    UserReputationEvent.create!(
      user_id: user2.id,
      event_type: :reputation_gained,
      points_change: 50,
      reason: 'leaderboard test'
    )

    leaderboard = ReputationLeaderboard.get_leaderboard('all_time')

    assert_equal 2, leaderboard.total_participants
    assert_equal @user_id, leaderboard.rankings_data.first[:user_id]
    assert_equal 100, leaderboard.rankings_data.first[:score]
  end

  test 'provides leaderboard data access methods' do
    leaderboard = ReputationLeaderboard.get_leaderboard('all_time')

    assert_respond_to leaderboard, :rankings_data
    assert_respond_to leaderboard, :top_user
    assert_respond_to leaderboard, :user_rank
    assert_respond_to leaderboard, :user_score
    assert_respond_to leaderboard, :percentile_rank
  end

  test 'calculates user position correctly' do
    user2 = users(:two)

    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 100,
      reason: 'position test'
    )

    UserReputationEvent.create!(
      user_id: user2.id,
      event_type: :reputation_gained,
      points_change: 75,
      reason: 'position test'
    )

    leaderboard = ReputationLeaderboard.get_leaderboard('all_time')

    assert_equal 1, leaderboard.user_rank(@user_id)
    assert_equal 2, leaderboard.user_rank(user2.id)
    assert_equal 100, leaderboard.user_score(@user_id)
    assert_equal 50.0, leaderboard.percentile_rank(@user_id) # Top 50%
  end

  test 'detects stale leaderboards' do
    leaderboard = ReputationLeaderboard.create!(
      leaderboard_type: 'daily',
      period_start: Date.current,
      period_end: Date.current,
      total_participants: 0,
      last_calculated_at: 30.minutes.ago
    )

    assert leaderboard.is_stale?

    leaderboard.update!(last_calculated_at: Time.current)
    assert_not leaderboard.is_stale?
  end

  test 'refreshes stale leaderboards' do
    leaderboard = ReputationLeaderboard.create!(
      leaderboard_type: 'daily',
      period_start: Date.current,
      period_end: Date.current,
      total_participants: 0,
      last_calculated_at: 30.minutes.ago
    )

    assert_changes -> { leaderboard.last_calculated_at } do
      leaderboard.refresh!
    end
  end

  # Test class methods for bulk operations
  test 'refreshes all summaries' do
    # Create test data
    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 50,
      reason: 'bulk refresh test'
    )

    updated_count = UserReputationSummary.refresh_all

    assert updated_count > 0
  end

  test 'gets leaderboard distribution' do
    # Create users with different levels
    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 200, # Trusted level
      reason: 'distribution test'
    )

    distribution = UserReputationSummary.distribution_by_level

    assert distribution.present?
    assert distribution.keys.include?('trusted')
  end

  test 'gets average score by level' do
    averages = UserReputationSummary.average_score_by_level

    assert averages.present?
    assert averages.values.all? { |avg| avg.is_a?(Numeric) }
  end

  test 'gets top users by score' do
    top_users = UserReputationSummary.top_users_by_score(5)

    assert top_users.present?
    assert top_users.first.total_score >= top_users.last.total_score
  end

  # Test error handling in read models
  test 'handles missing user gracefully' do
    summary = UserReputationSummary.refresh_for_user(99999)

    assert_equal 0, summary.total_score
    assert_equal 0, summary.events_count
    assert_equal 'restricted', summary.reputation_level
  end

  test 'handles empty data gracefully' do
    snapshot = ReputationAnalyticsSnapshot.generate_daily_snapshot(Date.yesterday)

    # Should handle empty data without errors
    assert_nil snapshot # No events yesterday
  end
end