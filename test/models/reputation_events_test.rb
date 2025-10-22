# frozen_string_literal: true

require 'test_helper'

class ReputationEventsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @aggregate_id = "user_reputation_#{@user.id}"
  end

  # Test ReputationGainedEvent
  test 'creates valid reputation gained event' do
    event = ReputationGainedEvent.new(
      @aggregate_id,
      user_id: @user.id,
      points_gained: 10,
      reason: 'test purchase',
      source_type: 'purchase',
      source_id: 'order_123'
    )

    assert event.valid?
    assert_equal 10, event.points_gained
    assert_equal 'test purchase', event.reason
    assert_equal 'ReputationGainedEvent', event.event_type
  end

  test 'calculates actual points with multiplier' do
    event = ReputationGainedEvent.new(
      @aggregate_id,
      user_id: @user.id,
      points_gained: 10,
      reason: 'test',
      reputation_multiplier: 1.5
    )

    assert_equal 15, event.actual_points_gained
  end

  test 'validates required fields for reputation gained event' do
    event = ReputationGainedEvent.new(@aggregate_id, user_id: nil, points_gained: 10, reason: '')

    assert_not event.valid?
    assert_includes event.errors[:user_id], "can't be blank"
    assert_includes event.errors[:points_gained], 'must be greater than 0'
    assert_includes event.errors[:reason], "can't be blank"
  end

  test 'validates multiplier range' do
    event = ReputationGainedEvent.new(
      @aggregate_id,
      user_id: @user.id,
      points_gained: 10,
      reason: 'test',
      reputation_multiplier: 10.0
    )

    assert_not event.valid?
    assert_includes event.errors[:reputation_multiplier], 'must be less than or equal to 5.0'
  end

  # Test ReputationLostEvent
  test 'creates valid reputation lost event' do
    event = ReputationLostEvent.new(
      @aggregate_id,
      user_id: @user.id,
      points_lost: 5,
      reason: 'spam violation',
      violation_type: 'spam',
      severity_level: 'medium'
    )

    assert event.valid?
    assert_equal 5, event.points_lost
    assert_equal 'spam', event.violation_type
    assert_equal 'ReputationLostEvent', event.event_type
  end

  test 'validates required fields for reputation lost event' do
    event = ReputationLostEvent.new(
      @aggregate_id,
      user_id: nil,
      points_lost: 5,
      reason: '',
      violation_type: ''
    )

    assert_not event.valid?
    assert_includes event.errors[:user_id], "can't be blank"
    assert_includes event.errors[:violation_type], "can't be blank"
  end

  test 'validates severity level' do
    event = ReputationLostEvent.new(
      @aggregate_id,
      user_id: @user.id,
      points_lost: 5,
      reason: 'test',
      violation_type: 'spam',
      severity_level: 'invalid'
    )

    assert_not event.valid?
    assert_includes event.errors[:severity_level], 'is not included in the list'
  end

  # Test ReputationLevelChangedEvent
  test 'creates valid level change event' do
    event = ReputationLevelChangedEvent.new(
      @aggregate_id,
      user_id: @user.id,
      old_level: 'regular',
      new_level: 'trusted',
      score_threshold: 150
    )

    assert event.valid?
    assert event.level_up?
    assert_not event.level_down?
    assert_equal 'ReputationLevelChangedEvent', event.event_type
  end

  test 'detects level down correctly' do
    event = ReputationLevelChangedEvent.new(
      @aggregate_id,
      user_id: @user.id,
      old_level: 'trusted',
      new_level: 'regular',
      score_threshold: 50
    )

    assert event.level_down?
    assert_not event.level_up?
  end

  # Test ReputationLevel value object
  test 'creates reputation level correctly' do
    level = ReputationLevel.new('trusted')

    assert_equal 'trusted', level.name
    assert_equal 4, level.rank
    assert level.allows?(:premium_features)
    assert level.can_access_premium_features?
    assert_not level.allows?(:moderate_content)
  end

  test 'maps scores to levels correctly' do
    assert_equal :restricted, ReputationLevel.from_score(-100)
    assert_equal :probation, ReputationLevel.from_score(-25)
    assert_equal :regular, ReputationLevel.from_score(50)
    assert_equal :trusted, ReputationLevel.from_score(200)
    assert_equal :exemplary, ReputationLevel.from_score(1000)
  end

  test 'exemplary level allows all permissions' do
    level = ReputationLevel.new('exemplary')

    assert level.allows?(:post_content)
    assert level.allows?(:moderate_content)
    assert level.allows?(:premium_features)
    assert level.allows?(:priority_support)
    assert level.can_post_content?
    assert level.can_moderate?
  end

  test 'restricted level allows no permissions' do
    level = ReputationLevel.new('restricted')

    assert_not level.allows?(:post_content)
    assert_not level.can_post_content?
    assert_not level.can_moderate?
  end

  # Test event serialization
  test 'serializes event data correctly' do
    event = ReputationGainedEvent.new(
      @aggregate_id,
      user_id: @user.id,
      points_gained: 10,
      reason: 'test',
      source_type: 'purchase'
    )

    event_data = event.event_data

    assert_equal @user.id, event_data[:user_id]
    assert_equal 10, event_data[:points_gained]
    assert_equal 'test', event_data[:reason]
    assert_equal 'purchase', event_data[:source_type]
  end

  test 'generates human readable descriptions' do
    gain_event = ReputationGainedEvent.new(
      @aggregate_id,
      user_id: @user.id,
      points_gained: 15,
      reason: 'product review'
    )

    loss_event = ReputationLostEvent.new(
      @aggregate_id,
      user_id: @user.id,
      points_lost: 10,
      reason: 'inappropriate content',
      violation_type: 'spam'
    )

    assert_equal 'User 1 gained 15 reputation points for: product review', gain_event.description
    assert_equal 'User 1 lost 10 reputation points for spam: inappropriate content', loss_event.description
  end
end