# frozen_string_literal: true

require 'test_helper'

class ReputationCommandsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @admin_user = users(:admin)
  end

  # Test GainReputationCommand
  test 'executes reputation gain successfully' do
    assert_difference 'UserReputationEvent.count', 1 do
      command = GainReputationCommand.new(
        user_id: @user.id,
        points: 10,
        reason: 'test purchase',
        source_type: 'purchase',
        source_id: 'order_123'
      )

      event = command.execute

      assert event.is_a?(ReputationGainedEvent)
      assert_equal 10, event.points_gained
      assert_equal @user.id, event.user_id
    end
  end

  test 'validates required fields for gain command' do
    assert_raises(ValidationError) do
      GainReputationCommand.new(
        user_id: nil,
        points: 10,
        reason: 'test'
      ).execute
    end

    assert_raises(ValidationError) do
      GainReputationCommand.new(
        user_id: @user.id,
        points: 0,
        reason: 'test'
      ).execute
    end

    assert_raises(ValidationError) do
      GainReputationCommand.new(
        user_id: @user.id,
        points: 10,
        reason: ''
      ).execute
    end
  end

  test 'validates user exists for gain command' do
    assert_raises(ValidationError) do
      GainReputationCommand.new(
        user_id: 99999,
        points: 10,
        reason: 'test'
      ).execute
    end
  end

  test 'applies multiplier correctly' do
    command = GainReputationCommand.new(
      user_id: @user.id,
      points: 10,
      reason: 'test',
      multiplier: 2.0
    )

    event = command.execute

    # The command should create an event with the base points
    # The multiplier is applied when calculating actual points
    assert_equal 10, event.points_gained
    assert_equal 2.0, event.reputation_multiplier
    assert_equal 20, event.actual_points_gained
  end

  # Test LoseReputationCommand
  test 'executes reputation loss successfully' do
    assert_difference 'UserReputationEvent.count', 1 do
      command = LoseReputationCommand.new(
        user_id: @user.id,
        points: 5,
        reason: 'spam violation',
        violation_type: 'spam',
        severity_level: 'medium'
      )

      event = command.execute

      assert event.is_a?(ReputationLostEvent)
      assert_equal 5, event.points_lost
      assert_equal 'spam', event.violation_type
    end
  end

  test 'validates required fields for loss command' do
    assert_raises(ValidationError) do
      LoseReputationCommand.new(
        user_id: @user.id,
        points: 5,
        reason: 'test',
        violation_type: ''
      ).execute
    end
  end

  test 'prevents too many recent penalties' do
    # Create multiple recent penalties
    3.times do |i|
      UserReputationEvent.create!(
        user_id: @user.id,
        event_type: :reputation_lost,
        points_change: -5,
        reason: "penalty #{i}",
        violation_type: 'spam',
        created_at: 30.minutes.ago
      )
    end

    assert_raises(ValidationError) do
      LoseReputationCommand.new(
        user_id: @user.id,
        points: 5,
        reason: 'another penalty',
        violation_type: 'spam'
      ).execute
    end
  end

  # Test ResetReputationCommand
  test 'executes reputation reset successfully' do
    # First give the user some reputation
    UserReputationEvent.create!(
      user_id: @user.id,
      event_type: :reputation_gained,
      points_change: 100,
      reason: 'initial points'
    )

    assert_difference 'UserReputationEvent.count', 1 do
      command = ResetReputationCommand.new(
        user_id: @user.id,
        admin_user_id: @admin_user.id,
        reset_reason: 'disciplinary action',
        new_score: 0
      )

      event = command.execute

      assert event.is_a?(ReputationResetEvent)
      assert_equal 100, event.previous_score
      assert_equal @admin_user.id, event.admin_user_id
    end
  end

  test 'validates admin permissions for reset' do
    regular_user = users(:two)

    assert_raises(ValidationError) do
      ResetReputationCommand.new(
        user_id: @user.id,
        admin_user_id: regular_user.id,
        reset_reason: 'test',
        new_score: 0
      ).execute
    end
  end

  test 'prevents too many recent resets' do
    # Create recent reset events
    2.times do |i|
      UserReputationEvent.create!(
        user_id: @user.id,
        event_type: :reputation_reset,
        points_change: -50,
        reason: "reset #{i}",
        admin_user_id: @admin_user.id,
        created_at: 12.hours.ago
      )
    end

    assert_raises(ValidationError) do
      ResetReputationCommand.new(
        user_id: @user.id,
        admin_user_id: @admin_user.id,
        reset_reason: 'another reset',
        new_score: 0
      ).execute
    end
  end

  # Test command error handling
  test 'handles database errors gracefully' do
    # Mock a database error
    UserReputationEvent.stub :create!, ->(*) { raise ActiveRecord::StatementInvalid.new('Database error') } do
      command = GainReputationCommand.new(
        user_id: @user.id,
        points: 10,
        reason: 'test'
      )

      assert_raises(CommandExecutionError) do
        command.execute
      end
    end
  end

  # Test transaction rollback on failure
  test 'rolls back transaction on validation error' do
    initial_count = UserReputationEvent.count

    assert_raises(ValidationError) do
      GainReputationCommand.new(
        user_id: nil, # Invalid user
        points: 10,
        reason: 'test'
      ).execute
    end

    # Should not have created any events
    assert_equal initial_count, UserReputationEvent.count
  end

  # Test level change detection
  test 'creates level change event when user levels up' do
    # Set user to high reputation level first
    @user.update!(reputation_level: 'regular')

    # Create events to reach trusted level threshold
    UserReputationEvent.create!(
      user_id: @user.id,
      event_type: :reputation_gained,
      points_change: 90, # Total will be 90, need 101 for trusted
      reason: 'setup'
    )

    assert_difference 'UserReputationEvent.count', 2 do # Gain event + level change event
      command = GainReputationCommand.new(
        user_id: @user.id,
        points: 15, # This should trigger level change (90 + 15 = 105)
        reason: 'level up trigger',
        source_type: 'purchase'
      )

      event = command.execute

      # Should have created a level change event
      level_change_event = UserReputationEvent.where(
        user_id: @user.id,
        event_type: :reputation_level_changed
      ).last

      assert level_change_event.present?
      assert_equal 'regular', level_change_event.previous_level
      assert_equal 'trusted', level_change_event.reputation_level
    end
  end

  # Test source type validation
  test 'validates source types correctly' do
    assert_raises(ValidationError) do
      GainReputationCommand.new(
        user_id: @user.id,
        points: 10,
        reason: 'test',
        source_type: 'invalid_source'
      ).execute
    end
  end

  # Test violation type validation
  test 'validates violation types correctly' do
    assert_raises(ValidationError) do
      LoseReputationCommand.new(
        user_id: @user.id,
        points: 5,
        reason: 'test',
        violation_type: 'invalid_violation'
      ).execute
    end
  end
end