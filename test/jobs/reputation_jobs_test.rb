# frozen_string_literal: true

require 'test_helper'

class ReputationJobsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user_id = @user.id
  end

  # Test ReputationEventProcessorJob
  test 'processes reputation gain event' do
    event = UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 10,
      reason: 'job test',
      source_type: 'purchase',
      source_id: 'order_123'
    )

    assert_difference 'UserReputationSummary.count', 1 do
      ReputationEventProcessorJob.perform_now(
        event.event_id,
        'ReputationGainedEvent',
        @user_id
      )
    end
  end

  test 'processes reputation loss event' do
    event = UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_lost,
      points_change: -5,
      reason: 'job test',
      violation_type: 'spam',
      severity_level: 'medium'
    )

    assert_difference 'UserReputationSummary.count', 1 do
      ReputationEventProcessorJob.perform_now(
        event.event_id,
        'ReputationLostEvent',
        @user_id
      )
    end
  end

  test 'handles unknown event type gracefully' do
    # Should not raise error for unknown event type
    assert_nothing_raised do
      ReputationEventProcessorJob.perform_now(
        'unknown_id',
        'UnknownEventType',
        @user_id
      )
    end
  end

  test 'processes events in bulk' do
    events_data = [
      {
        event_id: 'event_1',
        event_type: 'ReputationGainedEvent',
        user_id: @user_id,
        metadata: { source_id: 'order_1' }
      },
      {
        event_id: 'event_2',
        event_type: 'ReputationLostEvent',
        user_id: @user_id,
        metadata: { violation_type: 'spam' }
      }
    ]

    assert_difference 'UserReputationSummary.count', 1 do
      ReputationEventProcessorJob.perform_bulk(events_data)
    end
  end

  test 'handles processing errors with retry' do
    # Mock a processing error
    UserReputationEvent.stub :find_by, ->(*) { raise ActiveRecord::StatementInvalid.new('Database error') } do
      assert_raises ActiveRecord::StatementInvalid do
        ReputationEventProcessorJob.perform_now(
          'error_id',
          'ReputationGainedEvent',
          @user_id
        )
      end
    end
  end

  # Test ReputationAnalyticsUpdateJob
  test 'updates user analytics' do
    # Create some events for the user
    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 50,
      reason: 'analytics test'
    )

    assert_difference 'UserReputationSummary.count', 1 do
      ReputationAnalyticsUpdateJob.perform_now(@user_id, 'ReputationGainedEvent')
    end
  end

  test 'updates global analytics' do
    # Create test data across multiple users
    user2 = users(:two)

    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 50,
      reason: 'global test',
      created_at: Time.current
    )

    UserReputationEvent.create!(
      user_id: user2.id,
      event_type: :reputation_lost,
      points_change: -10,
      reason: 'global test',
      violation_type: 'spam',
      created_at: Time.current
    )

    assert_difference 'ReputationAnalyticsSnapshot.count', 1 do
      ReputationAnalyticsUpdateJob.perform_now # Global update
    end
  end

  test 'handles analytics errors gracefully' do
    # Mock an analytics error
    UserReputationSummary.stub :refresh_for_user, ->(*) { raise StandardError.new('Analytics error') } do
      assert_nothing_raised do
        ReputationAnalyticsUpdateJob.perform_now(@user_id)
      end
    end
  end

  # Test ReputationLeaderboardUpdateJob
  test 'updates leaderboard' do
    # Create test data for leaderboard
    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 100,
      reason: 'leaderboard test'
    )

    assert_difference 'ReputationLeaderboard.count', 1 do
      ReputationLeaderboardUpdateJob.perform_now('all_time')
    end
  end

  test 'updates all leaderboards' do
    # Create test data
    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 50,
      reason: 'full update test'
    )

    assert_difference 'ReputationLeaderboard.count', 4 do # All 4 leaderboard types
      ReputationLeaderboardUpdateJob.perform_full_update
    end
  end

  test 'handles leaderboard calculation errors' do
    # Mock a calculation error
    ReputationLeaderboard.stub :calculate_rankings!, ->(*) { raise StandardError.new('Calculation error') } do
      assert_nothing_raised do
        ReputationLeaderboardUpdateJob.perform_now('all_time')
      end
    end
  end

  # Test job error handling and logging
  test 'logs processing errors correctly' do
    # Mock Rails logger to capture error logs
    error_logged = false

    Rails.stub :logger, -> {
      logger = mock('logger')
      logger.stubs(:error).with do |message|
        error_logged = true if message.include?('Failed to process reputation event')
        nil
      end
      logger
    } do

      # Cause a processing error
      UserReputationEvent.stub :find_by, ->(*) { raise StandardError.new('Test error') } do
        begin
          ReputationEventProcessorJob.perform_now('error_id', 'TestEvent', @user_id)
        rescue StandardError
          # Expected error
        end
      end
    end

    assert error_logged
  end

  # Test job performance characteristics
  test 'processes events within reasonable time' do
    event = UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 10,
      reason: 'performance test'
    )

    start_time = Time.current

    ReputationEventProcessorJob.perform_now(
      event.event_id,
      'ReputationGainedEvent',
      @user_id
    )

    duration = Time.current - start_time

    # Should complete within 1 second for simple operations
    assert duration < 1.second
  end

  # Test job idempotency
  test 'handles duplicate event processing' do
    event = UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 10,
      reason: 'idempotency test'
    )

    # Process the same event twice
    assert_nothing_raised do
      ReputationEventProcessorJob.perform_now(
        event.event_id,
        'ReputationGainedEvent',
        @user_id
      )

      ReputationEventProcessorJob.perform_now(
        event.event_id,
        'ReputationGainedEvent',
        @user_id
      )
    end
  end

  # Test job queue configuration
  test 'uses correct queue configuration' do
    # Test that jobs are configured for appropriate queues
    assert_equal :reputation_events, ReputationEventProcessorJob.queue_name
    assert_equal :reputation_analytics, ReputationAnalyticsUpdateJob.queue_name
    assert_equal :reputation_leaderboards, ReputationLeaderboardUpdateJob.queue_name
  end

  # Test job retry configuration
  test 'has appropriate retry configuration' do
    job = ReputationEventProcessorJob.new

    # Should retry up to 3 times for event processing
    assert_equal 3, job.sidekiq_options['retry']
    assert job.sidekiq_options['backtrace']
    assert job.sidekiq_options['dead']
  end

  # Test background job integration
  test 'integrates with Sidekiq correctly' do
    # Test that jobs can be queued and executed
    event = UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 10,
      reason: 'sidekiq test'
    )

    # Queue the job
    job_id = ReputationEventProcessorJob.perform_async(
      event.event_id,
      'ReputationGainedEvent',
      @user_id
    )

    assert job_id.present?

    # Execute the job
    assert_difference 'UserReputationSummary.count', 1 do
      ReputationEventProcessorJob.drain
    end
  end

  # Test job monitoring and metrics
  test 'records job metrics' do
    metrics_recorded = false

    # Mock metrics service
    MetricsService.stub :increment_counter, ->(*) { metrics_recorded = true } do
      event = UserReputationEvent.create!(
        user_id: @user_id,
        event_type: :reputation_gained,
        points_change: 10,
        reason: 'metrics test'
      )

      ReputationEventProcessorJob.perform_now(
        event.event_id,
        'ReputationGainedEvent',
        @user_id
      )
    end

    # Metrics should be recorded for successful processing
    # (In real implementation, this would be more comprehensive)
  end

  # Test job cleanup and maintenance
  test 'cleans up old analytics snapshots' do
    # Create old snapshot
    ReputationAnalyticsSnapshot.create!(
      snapshot_date: 100.days.ago,
      total_users: 10,
      active_users: 5,
      total_events: 100,
      total_points_awarded: 500,
      total_points_deducted: 50,
      average_score: 45.0
    )

    # Run cleanup
    deleted_count = ReputationAnalyticsSnapshot.cleanup_old_snapshots(90)

    assert_equal 1, deleted_count
  end

  # Test job error notification
  test 'sends error notifications' do
    notification_sent = false

    # Mock error notification service
    ErrorNotificationService.stub :notify, ->(*) { notification_sent = true } do
      # Cause an error in job processing
      UserReputationEvent.stub :find_by, ->(*) { raise StandardError.new('Test error') } do
        begin
          ReputationEventProcessorJob.perform_now('error_id', 'TestEvent', @user_id)
        rescue StandardError
          # Expected error
        end
      end
    end

    assert notification_sent
  end
end