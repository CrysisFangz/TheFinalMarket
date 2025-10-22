# frozen_string_literal: true

# Service: Orchestrates reputation operations with async processing and resilience
# Coordinates between commands, services, and external systems for reputation management
class ReputationProcessingService
  include ServicePattern

  # Circuit breaker for external service calls
  include CircuitBreakerPattern

  attr_reader :user_id, :operation_type

  def initialize(user_id, operation_type = nil)
    @user_id = user_id
    @operation_type = operation_type
  end

  # Process reputation gain with full validation and async handling
  def process_reputation_gain(action_type, points, reason, metadata = {})
    with_circuit_breaker do
      # Validate the operation
      validation_service = ReputationValidationService.new(user_id, action_type, metadata)
      return failure_response('Validation failed', validation_service.validate_action) if validation_service.validate_action

      # Calculate actual points with business logic
      calculator = ReputationCalculationService.new(user_id, metadata)
      actual_points = calculator.calculate_action_points(action_type, metadata)

      return failure_response('No points to award', []) if actual_points <= 0

      # Execute the command
      command = GainReputationCommand.new(
        user_id: user_id,
        points: actual_points,
        reason: reason,
        source_type: action_type.to_s,
        source_id: metadata[:source_id],
        multiplier: metadata[:multiplier] || 1.0
      )

      event = command.execute

      # Trigger async processing
      trigger_async_processing(event, :gain)

      success_response('Reputation gained successfully', event)
    end
  rescue StandardError => e
    handle_error('Reputation gain processing failed', e)
  end

  # Process reputation penalty with severity assessment
  def process_reputation_penalty(violation_type, base_points, reason, metadata = {})
    with_circuit_breaker do
      # Validate the penalty
      validation_service = ReputationValidationService.new(user_id, :penalty, metadata)
      validation_errors = validation_service.validate_penalty(violation_type, metadata[:severity_level], metadata)

      return failure_response('Penalty validation failed', validation_errors) if validation_errors

      # Calculate actual penalty with business logic
      calculator = ReputationCalculationService.new(user_id, metadata)
      actual_penalty = calculator.calculate_violation_penalty(violation_type, metadata[:severity_level], metadata)

      return failure_response('No penalty to apply', []) if actual_penalty >= 0

      # Execute the penalty command
      command = LoseReputationCommand.new(
        user_id: user_id,
        points: actual_penalty.abs,
        reason: reason,
        violation_type: violation_type,
        severity_level: metadata[:severity_level] || 'medium'
      )

      event = command.execute

      # Trigger async processing
      trigger_async_processing(event, :penalty)

      success_response('Reputation penalty applied', event)
    end
  rescue StandardError => e
    handle_error('Reputation penalty processing failed', e)
  end

  # Process reputation reset (admin operation)
  def process_reputation_reset(admin_user_id, reason, new_score = 0, metadata = {})
    with_circuit_breaker do
      # Execute the reset command
      command = ResetReputationCommand.new(
        user_id: user_id,
        admin_user_id: admin_user_id,
        reset_reason: reason,
        new_score: new_score
      )

      event = command.execute

      # Trigger async processing for reset
      trigger_async_processing(event, :reset)

      success_response('Reputation reset successfully', event)
    end
  rescue StandardError => e
    handle_error('Reputation reset processing failed', e)
  end

  # Get comprehensive user reputation status
  def get_user_reputation_status
    with_circuit_breaker do
      query = UserReputationQuery.new(user_id, include_history: true)
      query.execute
    end
  rescue StandardError => e
    handle_error('Failed to retrieve reputation status', e)
  end

  # Process reputation decay for inactive users
  def process_reputation_decay
    with_circuit_breaker do
      # Find users eligible for decay
      eligible_users = find_users_for_decay

      processed_count = 0
      failed_count = 0

      eligible_users.each do |user_id|
        begin
          process_user_decay(user_id)
          processed_count += 1
        rescue StandardError => e
          Rails.logger.error("Failed to process decay for user #{user_id}: #{e.message}")
          failed_count += 1
        end
      end

      success_response(
        'Decay processing completed',
        {
          processed: processed_count,
          failed: failed_count,
          total: eligible_users.count
        }
      )
    end
  rescue StandardError => e
    handle_error('Reputation decay processing failed', e)
  end

  # Bulk reputation operations for efficiency
  def process_bulk_reputation_operations(operations)
    with_circuit_breaker do
      results = {
        successful: [],
        failed: [],
        total: operations.count
      }

      operations.each_with_index do |operation, index|
        begin
          result = process_single_operation(operation)
          results[:successful] << { index: index, result: result }
        rescue StandardError => e
          results[:failed] << { index: index, error: e.message }
        end
      end

      success_response('Bulk processing completed', results)
    end
  rescue StandardError => e
    handle_error('Bulk reputation processing failed', e)
  end

  private

  def with_circuit_breaker
    circuit_breaker = CircuitBreaker.new(
      failure_threshold: 5,
      recovery_timeout: 30.seconds,
      expected_exception: [ActiveRecord::ConnectionTimeoutError, ActiveRecord::StatementInvalid]
    )

    circuit_breaker.execute do
      yield
    end
  end

  def trigger_async_processing(event, operation_type)
    # Queue async processing for projections, notifications, etc.
    ReputationAsyncProcessor.perform_async(
      event.event_id,
      operation_type,
      event.user_id
    )

    # Trigger real-time notifications if needed
    trigger_real_time_notifications(event, operation_type)
  end

  def trigger_real_time_notifications(event, operation_type)
    # Send real-time updates via ActionCable
    case operation_type
    when :gain
      ReputationChannel.broadcast_to(
        "user_#{event.user_id}",
        type: 'reputation_gained',
        points: event.actual_points_gained,
        new_score: current_reputation_score(event.user_id),
        level: current_reputation_level(event.user_id)
      )
    when :penalty
      ReputationChannel.broadcast_to(
        "user_#{event.user_id}",
        type: 'reputation_penalty',
        points_lost: event.points_lost,
        new_score: current_reputation_score(event.user_id),
        level: current_reputation_level(event.user_id)
      )
    when :reset
      ReputationChannel.broadcast_to(
        "user_#{event.user_id}",
        type: 'reputation_reset',
        new_score: event.new_score || 0,
        level: current_reputation_level(event.user_id)
      )
    end
  end

  def find_users_for_decay
    # Find users who haven't had reputation activity in 30+ days
    inactive_threshold = 30.days.ago

    UserReputationEvent.where('created_at < ?', inactive_threshold)
                      .group(:user_id)
                      .having('MAX(created_at) < ?', inactive_threshold)
                      .pluck(:user_id)
  end

  def process_user_decay(user_id)
    calculator = ReputationCalculationService.new(user_id)

    # Calculate days inactive
    last_activity = UserReputationEvent.where(user_id: user_id)
                                      .maximum(:created_at)

    days_inactive = ((Time.current - last_activity) / 1.day).to_i

    # Calculate decay points
    decay_points = calculator.calculate_decay_points(days_inactive)

    return if decay_points <= 0

    # Apply decay as a special type of reputation loss
    command = LoseReputationCommand.new(
      user_id: user_id,
      points: decay_points,
      reason: 'Reputation decay due to inactivity',
      violation_type: 'inactivity',
      severity_level: 'low'
    )

    command.execute
  end

  def process_single_operation(operation)
    case operation[:type].to_sym
    when :gain
      process_reputation_gain(
        operation[:action_type],
        operation[:points],
        operation[:reason],
        operation[:metadata] || {}
      )
    when :penalty
      process_reputation_penalty(
        operation[:violation_type],
        operation[:points],
        operation[:reason],
        operation[:metadata] || {}
      )
    when :reset
      process_reputation_reset(
        operation[:admin_user_id],
        operation[:reason],
        operation[:new_score] || 0,
        operation[:metadata] || {}
      )
    else
      raise "Unknown operation type: #{operation[:type]}"
    end
  end

  def current_reputation_score(user_id)
    UserReputationEvent.where(user_id: user_id).sum(:points_change)
  end

  def current_reputation_level(user_id)
    score = current_reputation_score(user_id)
    ReputationLevel.from_score(score).to_s
  end

  def success_response(message, data)
    {
      success: true,
      message: message,
      data: data,
      timestamp: Time.current
    }
  end

  def failure_response(message, errors)
    {
      success: false,
      message: message,
      errors: errors,
      timestamp: Time.current
    }
  end

  def handle_error(message, error)
    Rails.logger.error("#{message}: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))

    failure_response(message, [error.message])
  end
end