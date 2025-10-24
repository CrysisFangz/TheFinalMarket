class ReviewNotificationService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'review_notification'
  CACHE_TTL = 5.minutes

  def self.notify_owner(review)
    cache_key = "#{CACHE_KEY_PREFIX}:notify:#{review.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_notification') do
        with_retry do
          owner = review.reviewable_type == 'User' ? review.reviewable : review.reviewable.user

          notification = owner.notify(
            actor: review.reviewer,
            action: 'new_review',
            notifiable: review
          )

          EventPublisher.publish('review.owner_notified', {
            review_id: review.id,
            reviewer_id: review.reviewer_id,
            owner_id: owner.id,
            reviewable_type: review.reviewable_type,
            reviewable_id: review.reviewable_id,
            rating: review.rating,
            notification_id: notification&.id
          })

          notification
        end
      end
    end
  end

  def self.notify_mentioned_users(review)
    cache_key = "#{CACHE_KEY_PREFIX}:mentions:#{review.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_notification') do
        with_retry do
          # Extract mentioned users from content (assuming @username format)
          mentioned_usernames = review.content.scan(/@(\w+)/).flatten
          mentioned_users = User.where(username: mentioned_usernames)

          notifications = mentioned_users.map do |user|
            user.notify(
              actor: review.reviewer,
              action: 'mentioned_in_review',
              notifiable: review
            )
          end

          if notifications.any?
            EventPublisher.publish('review.users_mentioned', {
              review_id: review.id,
              reviewer_id: review.reviewer_id,
              mentioned_user_ids: mentioned_users.pluck(:id),
              mention_count: mentioned_users.count
            })
          end

          notifications
        end
      end
    end
  end

  def self.notify_review_flagged(review, flag_reason)
    cache_key = "#{CACHE_KEY_PREFIX}:flagged:#{review.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_notification') do
        with_retry do
          # Notify moderators about flagged review
          moderators = User.where(role: 'moderator')
          notifications = moderators.map do |moderator|
            moderator.notify(
              actor: review.reviewer,
              action: 'review_flagged',
              notifiable: review,
              metadata: { flag_reason: flag_reason }
            )
          end

          EventPublisher.publish('review.flagged_for_moderation', {
            review_id: review.id,
            reviewer_id: review.reviewer_id,
            flag_reason: flag_reason,
            moderator_count: moderators.count
          })

          notifications
        end
      end
    end
  end

  def self.send_review_digest(user, reviews)
    cache_key = "#{CACHE_KEY_PREFIX}:digest:#{user.id}:#{reviews.first&.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_notification') do
        with_retry do
          ReviewNotificationMailer.digest(user, reviews).deliver_later

          EventPublisher.publish('review.digest_sent', {
            user_id: user.id,
            review_count: reviews.count,
            review_ids: reviews.pluck(:id)
          })

          true
        end
      end
    end
  end

  def self.clear_notification_cache(review_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:notify:#{review_id}",
      "#{CACHE_KEY_PREFIX}:mentions:#{review_id}",
      "#{CACHE_KEY_PREFIX}:flagged:#{review_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end