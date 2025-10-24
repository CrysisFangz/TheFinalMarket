# frozen_string_literal: true

require 'test_helper'

class ReputationServicesTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user_id = @user.id
  end

  # Test ReputationCalculationService
  test 'calculates action points correctly' do
    service = ReputationCalculationService.new(@user_id)

    # Test basic purchase points
    points = service.calculate_action_points(:purchase_completion, {})

    assert_equal 10, points # Base points for purchase
  end

  test 'applies quality multiplier for reviews' do
    service = ReputationCalculationService.new(@user_id)

    metadata = {
      review_length: 250,
      has_images: true,
      helpful_votes: 8,
      verified_purchase: true
    }

    points = service.calculate_action_points(:review_submission, metadata)

    # Should be higher than base 5 due to quality multipliers
    assert points > 5
  end

  test 'applies recency multiplier' do
    service = ReputationCalculationService.new(@user_id)

    # Create recent activity
    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 5,
      reason: 'recent activity',
      created_at: 3.days.ago
    )

    points = service.calculate_action_points(:purchase_completion, {})

    # Should be higher than base due to recency bonus
    assert points > 10
  end

  test 'calculates violation penalty correctly' do
    service = ReputationCalculationService.new(@user_id)

    penalty = service.calculate_violation_penalty(:spam, 'medium', {})

    assert_equal(-10, penalty) # Base penalty for spam
  end

  test 'applies severity multiplier to penalties' do
    service = ReputationCalculationService.new(@user_id)

    medium_penalty = service.calculate_violation_penalty(:spam, 'medium', {})
    high_penalty = service.calculate_violation_penalty(:spam, 'high', {})

    assert high_penalty < medium_penalty # More negative = harsher penalty
    assert_equal(-10, medium_penalty)
    assert_equal(-15, high_penalty)
  end

  test 'calculates reputation decay for inactive users' do
    service = ReputationCalculationService.new(@user_id)

    # Set user score first
    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 100,
      reason: 'initial score'
    )

    decay_points = service.calculate_decay_points(45) # 45 days inactive

    assert decay_points > 0
    assert decay_points < 100 # Should not decay more than current score
  end

  test 'calculates activity bonus for consistent users' do
    service = ReputationCalculationService.new(@user_id)

    # Create consistent daily activity for 10 days
    10.times do |i|
      UserReputationEvent.create!(
        user_id: @user_id,
        event_type: :reputation_gained,
        points_change: 5,
        reason: 'daily activity',
        created_at: (i + 1).days.ago
      )
    end

    bonus = service.calculate_activity_bonus

    assert bonus > 0
  end

  test 'calculates level progression correctly' do
    service = ReputationCalculationService.new(@user_id)

    progression = service.calculate_level_progression(50)

    assert_equal :trusted, progression[:next_level]
    assert_equal 51, progression[:points_needed] # 101 - 50
  end

  test 'calculates reputation velocity correctly' do
    service = ReputationCalculationService.new(@user_id)

    # Create events over 7 days
    7.times do |i|
      UserReputationEvent.create!(
        user_id: @user_id,
        event_type: :reputation_gained,
        points_change: 10,
        reason: 'daily gain',
        created_at: (i + 1).days.ago
      )
    end

    velocity = service.calculate_reputation_velocity(7)

    assert_equal 10.0, velocity # 70 points / 7 days = 10 per day
  end

  test 'calculates stability score correctly' do
    service = ReputationCalculationService.new(@user_id)

    # Create consistent daily gains
    7.times do |i|
      UserReputationEvent.create!(
        user_id: @user_id,
        event_type: :reputation_gained,
        points_change: 10,
        reason: 'consistent gain',
        created_at: (i + 1).days.ago
      )
    end

    stability = service.calculate_stability_score(7)

    assert stability > 80 # Should be high for consistent gains
  end

  # Test ReputationValidationService
  test 'validates valid action correctly' do
    service = ReputationValidationService.new(@user_id, :purchase_completion)

    errors = service.validate_action

    assert_nil errors
  end

  test 'rejects invalid action type' do
    service = ReputationValidationService.new(@user_id, :invalid_action)

    errors = service.validate_action

    assert_includes errors, 'Invalid action type'
  end

  test 'rejects restricted users' do
    @user.update!(reputation_level: 'restricted')

    service = ReputationValidationService.new(@user_id, :purchase_completion)

    errors = service.validate_action

    assert_includes errors, 'User is restricted from reputation actions'
  end

  test 'rejects users with too low reputation' do
    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_lost,
      points_change: -150,
      reason: 'penalty',
      violation_type: 'spam'
    )

    service = ReputationValidationService.new(@user_id, :purchase_completion)

    errors = service.validate_action

    assert_includes errors, 'User reputation too low for actions'
  end

  test 'validates penalty correctly' do
    service = ReputationValidationService.new(@user_id, :penalty)

    errors = service.validate_penalty(:spam, 'medium', {})

    assert_nil errors
  end

  test 'rejects invalid violation type' do
    service = ReputationValidationService.new(@user_id, :penalty)

    errors = service.validate_penalty(:invalid_violation, 'medium', {})

    assert_includes errors, 'Invalid violation type'
  end

  test 'rejects invalid severity level' do
    service = ReputationValidationService.new(@user_id, :penalty)

    errors = service.validate_penalty(:spam, 'invalid_severity', {})

    assert_includes errors, 'Invalid severity level'
  end

  test 'provides rate limit status' do
    service = ReputationValidationService.new(@user_id, :purchase_completion)

    status = service.rate_limit_status

    assert_includes status.keys, :hourly_used
    assert_includes status.keys, :hourly_limit
    assert_includes status.keys, :daily_used
    assert_includes status.keys, :daily_limit
    assert_includes status.keys, :next_reset
  end

  test 'checks if user can act' do
    service = ReputationValidationService.new(@user_id, :purchase_completion)

    assert service.can_user_act?

    # Test with restricted user
    @user.update!(reputation_level: 'restricted')

    assert_not service.can_user_act?
  end

  # Test ReputationProcessingService
  test 'processes reputation gain successfully' do
    service = ReputationProcessingService.new(@user_id)

    assert_difference 'UserReputationEvent.count', 1 do
      result = service.process_reputation_gain(
        :purchase_completion,
        10,
        'test purchase',
        { source_id: 'order_123' }
      )

      assert result[:success]
      assert_equal 'Reputation gained successfully', result[:message]
    end
  end

  test 'processes reputation penalty successfully' do
    service = ReputationProcessingService.new(@user_id)

    assert_difference 'UserReputationEvent.count', 1 do
      result = service.process_reputation_penalty(
        :spam,
        10,
        'spam violation',
        { severity_level: 'medium' }
      )

      assert result[:success]
      assert_equal 'Reputation penalty applied', result[:message]
    end
  end

  test 'processes reputation reset successfully' do
    service = ReputationProcessingService.new(@user_id)

    assert_difference 'UserReputationEvent.count', 1 do
      result = service.process_reputation_reset(
        @admin_user.id,
        'disciplinary action',
        0
      )

      assert result[:success]
      assert_equal 'Reputation reset successfully', result[:message]
    end
  end

  test 'returns failure response for invalid operations' do
    service = ReputationValidationService.new(99999, :purchase_completion) # Non-existent user

    # This should fail validation
    result = service.validate_action

    assert result.present?
    assert_includes result, 'User not found'
  end

  test 'handles service errors gracefully' do
    service = ReputationProcessingService.new(@user_id)

    # Mock a service error
    ReputationCalculationService.stub :new, ->(*) { raise StandardError.new('Calculation error') } do
      result = service.process_reputation_gain(:purchase_completion, 10, 'test')

      assert_not result[:success]
      assert_includes result[:message], 'Reputation gain processing failed'
    end
  end

  # Test decay processing
  test 'processes reputation decay for inactive users' do
    service = ReputationProcessingService.new(@user_id)

    # Set up user with reputation but no recent activity
    UserReputationEvent.create!(
      user_id: @user_id,
      event_type: :reputation_gained,
      points_change: 100,
      reason: 'initial',
      created_at: 45.days.ago # Old enough for decay
    )

    result = service.process_reputation_decay

    assert result[:success]
    assert result[:data][:processed] > 0
  end

  # Test bulk operations
  test 'processes bulk reputation operations' do
    service = ReputationProcessingService.new(@user_id)

    operations = [
      {
        type: :gain,
        action_type: :purchase_completion,
        points: 10,
        reason: 'bulk test 1',
        metadata: { source_id: 'order_1' }
      },
      {
        type: :gain,
        action_type: :review_submission,
        points: 5,
        reason: 'bulk test 2',
        metadata: { source_id: 'review_1' }
      }
    ]

    result = service.process_bulk_reputation_operations(operations)

    assert result[:success]
    assert_equal 2, result[:data][:successful].count
    assert_equal 0, result[:data][:failed].count
  end

  # Test circuit breaker integration
  test 'handles circuit breaker failures' do
    service = ReputationProcessingService.new(@user_id)

    # Mock circuit breaker to be open
    ReputationCircuitBreaker.instance.stub :execute_calculation, -> { raise CircuitBreaker::OpenCircuitError.new(nil) } do
      result = service.process_reputation_gain(:purchase_completion, 10, 'test')

      assert_not result[:success]
      assert_includes result[:errors].first, 'Circuit breaker is OPEN'
    end
  end
end