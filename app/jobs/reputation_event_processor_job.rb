# frozen_string_literal: true

# Background Job: Processes reputation events asynchronously
# Handles projections, notifications, and read model updates
class ReputationEventProcessorJob
  include Sidekiq::Worker

  sidekiq_options(
    queue: :reputation_events,
    retry: 3,
    backtrace: true,
    dead: true
  )

  # Process a single reputation event
  def perform(event_id, event_type, user_id, metadata = {})
    # Find and validate the event
    event = find_event(event_id, event_type)
    return unless event

    # Process based on event type
    case event_type
    when 'ReputationGainedEvent'
      process_reputation_gain(event, metadata)
    when 'ReputationLostEvent'
      process_reputation_loss(event, metadata)
    when 'ReputationResetEvent'
      process_reputation_reset(event, metadata)
    when 'ReputationLevelChangedEvent'
      process_level_change(event, metadata)
    else
      Rails.logger.warn("Unknown reputation event type: #{event_type}")
    end

  rescue StandardError => e
    handle_processing_error(event_id, event_type, e)
    raise # Re-raise for Sidekiq retry logic
  end

  # Bulk process multiple events for efficiency
  def self.perform_bulk(event_data_array)
    event_data_array.each do |event_data|
      perform_async(
        event_data['event_id'],
        event_data['event_type'],
        event_data['user_id'],
        event_data['metadata']
      )
    end
  end

  private

  def find_event(event_id, event_type)
    # This would typically query the event store
    # For now, we'll use the ActiveRecord model
    UserReputationEvent.find_by(
      event_id: event_id,
      event_type: event_type.demodulize.underscore
    )
  end

  def process_reputation_gain(event, metadata)
    Rails.logger.info("Processing reputation gain: #{event.points_change} points for user #{event.user_id}")

    # Update read models
    update_read_models(event)

    # Send notifications
    send_gain_notifications(event, metadata)

    # Update analytics
    update_analytics(event)

    # Check for achievements
    check_achievements(event)

    # Update leaderboards
    update_leaderboards(event)
  end

  def process_reputation_loss(event, metadata)
    Rails.logger.info("Processing reputation loss: #{event.points_change} points for user #{event.user_id}")

    # Update read models
    update_read_models(event)

    # Send notifications (more urgent for losses)
    send_loss_notifications(event, metadata)

    # Escalate if high severity
    escalate_high_severity_loss(event, metadata)

    # Update analytics
    update_analytics(event)

    # Update leaderboards
    update_leaderboards(event)
  end

  def process_reputation_reset(event, metadata)
    Rails.logger.info("Processing reputation reset for user #{event.user_id}")

    # Update read models
    update_read_models(event)

    # Send admin notification
    send_reset_notifications(event, metadata)

    # Update analytics
    update_analytics(event)

    # Update leaderboards
    update_leaderboards(event)

    # Log admin action
    log_admin_action(event, metadata)
  end

  def process_level_change(event, metadata)
    Rails.logger.info("Processing level change: #{event.old_level} -> #{event.new_level} for user #{event.user_id}")

    # Update read models
    update_read_models(event)

    # Send level change notifications
    send_level_change_notifications(event, metadata)

    # Trigger level-specific actions
    trigger_level_actions(event, metadata)

    # Update leaderboards
    update_leaderboards(event)
  end

  def update_read_models(event)
    # Update user reputation summary
    UserReputationSummary.refresh_for_user(event.user_id)

    # Queue analytics snapshot update (less frequent)
    if should_update_analytics_snapshot?
      ReputationAnalyticsUpdateJob.perform_in(5.minutes, event.user_id)
    end
  end

  def send_gain_notifications(event, metadata)
    # Send real-time notification to user
    ReputationNotificationService.notify_gain(
      user_id: event.user_id,
      points: event.points_change,
      reason: event.reason,
      new_level: current_reputation_level(event.user_id)
    )

    # Send notification to source (if applicable)
    if event.source_type && event.source_id
      send_source_notification(event, :gain)
    end
  end

  def send_loss_notifications(event, metadata)
    # Send real-time notification to user
    ReputationNotificationService.notify_loss(
      user_id: event.user_id,
      points: event.points_change.abs,
      reason: event.reason,
      violation_type: event.violation_type,
      severity: event.severity_level
    )

    # Notify moderators for high severity
    if event.high_severity?
      notify_moderators(event)
    end
  end

  def send_reset_notifications(event, metadata)
    # Notify user of reset
    ReputationNotificationService.notify_reset(
      user_id: event.user_id,
      previous_score: event.previous_score,
      new_score: 0,
      reason: event.reset_reason
    )

    # Notify admin who performed the reset
    notify_admin_of_reset(event, metadata)
  end

  def send_level_change_notifications(event, metadata)
    # Send level change notification
    ReputationNotificationService.notify_level_change(
      user_id: event.user_id,
      old_level: event.old_level,
      new_level: event.new_level,
      score_threshold: event.score_threshold
    )

    # Send achievement notifications for major level ups
    if event.level_up? && %w[trusted exemplary].include?(event.new_level)
      send_achievement_notification(event)
    end
  end

  def trigger_level_actions(event, metadata)
    case event.new_level
    when 'trusted'
      unlock_trusted_features(event.user_id)
    when 'exemplary'
      unlock_exemplary_features(event.user_id)
    when 'restricted'
      restrict_user_features(event.user_id)
    when 'probation'
      probation_user_features(event.user_id)
    end
  end

  def update_analytics(event)
    # Queue analytics update for later
    ReputationAnalyticsUpdateJob.perform_async(event.user_id, event.event_type)
  end

  def check_achievements(event)
    # Check for reputation-based achievements
    user_score = current_reputation_score(event.user_id)

    achievements_to_check = [
      { threshold: 100, name: 'Rising Star' },
      { threshold: 500, name: 'Trusted Contributor' },
      { threshold: 1000, name: 'Reputation Master' }
    ]

    achievements_to_check.each do |achievement|
      if user_score >= achievement[:threshold]
        award_achievement(event.user_id, achievement[:name])
      end
    end
  end

  def update_leaderboards(event)
    # Update relevant leaderboards
    leaderboard_types = determine_relevant_leaderboards(event)

    leaderboard_types.each do |type|
      ReputationLeaderboardUpdateJob.perform_async(type)
    end
  end

  def escalate_high_severity_loss(event, metadata)
    return unless event.high_severity?

    # Create moderation ticket
    ModerationTicket.create!(
      user_id: event.user_id,
      ticket_type: :reputation_violation,
      severity: event.severity_level,
      description: "High severity reputation violation: #{event.violation_type}",
      metadata: {
        event_id: event.event_id,
        points_lost: event.points_lost,
        reason: event.reason
      }
    )

    # Notify moderation team
    notify_moderation_team(event)
  end

  def send_source_notification(event, notification_type)
    # Send notification to the source of the reputation change
    case event.source_type
    when 'purchase'
      notify_purchase_source(event, notification_type)
    when 'review'
      notify_review_source(event, notification_type)
    when 'referral'
      notify_referral_source(event, notification_type)
    end
  end

  def notify_moderators(event)
    # Send notification to moderators about the reputation loss
    ModeratorNotificationService.notify_reputation_penalty(
      user_id: event.user_id,
      points_lost: event.points_lost,
      violation_type: event.violation_type,
      severity: event.severity_level
    )
  end

  def notify_moderation_team(event)
    # Send urgent notification to moderation team
    ModerationTeamNotificationService.notify_urgent(
      title: 'High Severity Reputation Violation',
      message: "User #{event.user_id} lost #{event.points_lost} reputation points",
      priority: :high,
      action_url: Rails.application.routes.url_helpers.user_path(event.user_id)
    )
  end

  def notify_admin_of_reset(event, metadata)
    # Notify the admin who performed the reset
    AdminNotificationService.notify(
      admin_user_id: event.admin_user_id,
      title: 'Reputation Reset Completed',
      message: "Reputation reset completed for user #{event.user_id}",
      action_url: Rails.application.routes.url_helpers.user_path(event.user_id)
    )
  end

  def send_achievement_notification(event)
    # Send achievement notification for major milestones
    AchievementNotificationService.notify(
      user_id: event.user_id,
      achievement_type: :reputation_milestone,
      level: event.new_level,
      message: "Congratulations! You've reached #{event.new_level} level!"
    )
  end

  def unlock_trusted_features(user_id)
    # Unlock features for trusted users
    UserFeatureService.unlock_features(user_id, :trusted_level_features)
  end

  def unlock_exemplary_features(user_id)
    # Unlock features for exemplary users
    UserFeatureService.unlock_features(user_id, :exemplary_level_features)
  end

  def restrict_user_features(user_id)
    # Restrict features for restricted users
    UserFeatureService.restrict_features(user_id, :posting_features)
  end

  def probation_user_features(user_id)
    # Apply probation restrictions
    UserFeatureService.restrict_features(user_id, :premium_features)
  end

  def award_achievement(user_id, achievement_name)
    # Award achievement to user
    UserAchievementService.award(
      user_id: user_id,
      achievement_type: :reputation,
      achievement_name: achievement_name
    )
  end

  def determine_relevant_leaderboards(event)
    # Determine which leaderboards need updating based on event timing
    current_time = Time.current

    leaderboards = []

    # Daily leaderboard (if event is from today)
    leaderboards << 'daily' if event.created_at.to_date == current_time.to_date

    # Weekly leaderboard (if event is from current week)
    leaderboards << 'weekly' if event.created_at.beginning_of_week == current_time.beginning_of_week

    # Monthly leaderboard (if event is from current month)
    leaderboards << 'monthly' if event.created_at.beginning_of_month == current_time.beginning_of_month

    # All-time leaderboard (always)
    leaderboards << 'all_time'

    leaderboards.uniq
  end

  def should_update_analytics_snapshot?
    # Only update analytics snapshot periodically to avoid overhead
    rand(1..100) <= 10 # 10% chance for each event
  end

  def current_reputation_score(user_id)
    UserReputationEvent.where(user_id: user_id).sum(:points_change)
  end

  def current_reputation_level(user_id)
    score = current_reputation_score(user_id)
    ReputationLevel.from_score(score).to_s
  end

  def handle_processing_error(event_id, event_type, error)
    Rails.logger.error("Failed to process reputation event #{event_id} (type: #{event_type}): #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))

    # Send error notification to monitoring
    ErrorNotificationService.notify(
      service: 'ReputationEventProcessor',
      error: error,
      context: {
        event_id: event_id,
        event_type: event_type
      }
    )
  end
end