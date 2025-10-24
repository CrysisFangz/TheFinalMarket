class ReviewInvitationEmailService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'review_invitation_email'
  CACHE_TTL = 5.minutes

  def self.send_invitation_email(invitation)
    cache_key = "#{CACHE_KEY_PREFIX}:invitation:#{invitation.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation_email') do
        with_retry do
          ReviewInvitationMailer.with(review_invitation: invitation).invitation_email.deliver_later

          EventPublisher.publish('review_invitation.email_sent', {
            invitation_id: invitation.id,
            user_id: invitation.user_id,
            order_id: invitation.order_id,
            item_id: invitation.item_id,
            email_type: 'invitation',
            sent_at: Time.current
          })

          true
        end
      end
    end
  end

  def self.send_expiry_notification(invitation)
    cache_key = "#{CACHE_KEY_PREFIX}:expiry:#{invitation.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation_email') do
        with_retry do
          ReviewInvitationMailer.expired(invitation).deliver_later

          EventPublisher.publish('review_invitation.email_sent', {
            invitation_id: invitation.id,
            user_id: invitation.user_id,
            order_id: invitation.order_id,
            item_id: invitation.item_id,
            email_type: 'expiry_notification',
            sent_at: Time.current
          })

          true
        end
      end
    end
  end

  def self.send_extension_notification(invitation, additional_days)
    cache_key = "#{CACHE_KEY_PREFIX}:extension:#{invitation.id}:#{additional_days}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation_email') do
        with_retry do
          ReviewInvitationMailer.extended(invitation, additional_days).deliver_later

          EventPublisher.publish('review_invitation.email_sent', {
            invitation_id: invitation.id,
            user_id: invitation.user_id,
            order_id: invitation.order_id,
            item_id: invitation.item_id,
            email_type: 'extension_notification',
            additional_days: additional_days,
            sent_at: Time.current
          })

          true
        end
      end
    end
  end

  def self.send_reminder_email(invitation, days_remaining)
    cache_key = "#{CACHE_KEY_PREFIX}:reminder:#{invitation.id}:#{days_remaining}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation_email') do
        with_retry do
          ReviewInvitationMailer.reminder(invitation, days_remaining).deliver_later

          EventPublisher.publish('review_invitation.email_sent', {
            invitation_id: invitation.id,
            user_id: invitation.user_id,
            order_id: invitation.order_id,
            item_id: invitation.item_id,
            email_type: 'reminder',
            days_remaining: days_remaining,
            sent_at: Time.current
          })

          true
        end
      end
    end
  end

  def self.send_bulk_reminders(invitations, days_remaining)
    cache_key = "#{CACHE_KEY_PREFIX}:bulk_reminder:#{invitations.count}:#{days_remaining}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation_email') do
        with_retry do
          invitations.each do |invitation|
            send_reminder_email(invitation, days_remaining)
          end

          EventPublisher.publish('review_invitation.bulk_email_sent', {
            invitation_ids: invitations.pluck(:id),
            user_ids: invitations.pluck(:user_id),
            email_type: 'bulk_reminder',
            days_remaining: days_remaining,
            count: invitations.count,
            sent_at: Time.current
          })

          invitations.count
        end
      end
    end
  end

  def self.send_completion_confirmation(invitation)
    cache_key = "#{CACHE_KEY_PREFIX}:completion:#{invitation.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation_email') do
        with_retry do
          ReviewInvitationMailer.completed(invitation).deliver_later

          EventPublisher.publish('review_invitation.email_sent', {
            invitation_id: invitation.id,
            user_id: invitation.user_id,
            order_id: invitation.order_id,
            item_id: invitation.item_id,
            email_type: 'completion_confirmation',
            sent_at: Time.current
          })

          true
        end
      end
    end
  end

  def self.clear_email_cache(invitation_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:invitation:#{invitation_id}",
      "#{CACHE_KEY_PREFIX}:expiry:#{invitation_id}",
      "#{CACHE_KEY_PREFIX}:extension:#{invitation_id}",
      "#{CACHE_KEY_PREFIX}:reminder:#{invitation_id}",
      "#{CACHE_KEY_PREFIX}:completion:#{invitation_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end