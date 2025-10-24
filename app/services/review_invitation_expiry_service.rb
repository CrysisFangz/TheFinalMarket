class ReviewInvitationExpiryService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'review_invitation_expiry'
  CACHE_TTL = 10.minutes

  def self.process_expired_invitations
    cache_key = "#{CACHE_KEY_PREFIX}:process_expired"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation_expiry') do
        with_retry do
          expired_invitations = ReviewInvitation.active.where('expires_at <= ?', Time.current)

          expired_invitations.each do |invitation|
            expire_invitation(invitation)
          end

          EventPublisher.publish('review_invitation.expiry_batch_processed', {
            processed_count: expired_invitations.count,
            processed_at: Time.current
          })

          expired_invitations.count
        end
      end
    end
  end

  def self.expire_invitation(invitation)
    cache_key = "#{CACHE_KEY_PREFIX}:expire_single:#{invitation.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation_expiry') do
        with_retry do
          return unless invitation.pending? && invitation.expires_at <= Time.current

          invitation.transaction do
            invitation.update!(status: :expired)
            notify_expiry(invitation)
          end

          EventPublisher.publish('review_invitation.expired', {
            invitation_id: invitation.id,
            user_id: invitation.user_id,
            order_id: invitation.order_id,
            item_id: invitation.item_id,
            expired_at: Time.current,
            original_expires_at: invitation.expires_at
          })

          true
        end
      end
    end
  end

  def self.notify_expiry(invitation)
    cache_key = "#{CACHE_KEY_PREFIX}:notify:#{invitation.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation_expiry') do
        with_retry do
          ReviewInvitationMailer.expired(invitation).deliver_later

          EventPublisher.publish('review_invitation.expiry_notified', {
            invitation_id: invitation.id,
            user_id: invitation.user_id,
            order_id: invitation.order_id,
            item_id: invitation.item_id,
            notified_at: Time.current
          })

          true
        end
      end
    end
  end

  def self.schedule_expiry_job(invitation)
    cache_key = "#{CACHE_KEY_PREFIX}:schedule:#{invitation.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation_expiry') do
        with_retry do
          # Schedule a job to expire the invitation when it expires
          ReviewInvitationExpiryJob.set(wait_until: invitation.expires_at).perform_later(invitation.id)

          EventPublisher.publish('review_invitation.expiry_scheduled', {
            invitation_id: invitation.id,
            user_id: invitation.user_id,
            scheduled_for: invitation.expires_at
          })

          true
        end
      end
    end
  end

  def self.get_expiring_soon(user_id, within_days = 3)
    cache_key = "#{CACHE_KEY_PREFIX}:expiring_soon:#{user_id}:#{within_days}"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      with_circuit_breaker('review_invitation_expiry') do
        with_retry do
          expiry_threshold = within_days.days.from_now
          ReviewInvitation.active
                         .where(user_id: user_id)
                         .where('expires_at <= ?', expiry_threshold)
                         .includes(:order, :item)
                         .to_a
        end
      end
    end
  end

  def self.extend_expiry(invitation, additional_days = 7)
    cache_key = "#{CACHE_KEY_PREFIX}:extend:#{invitation.id}:#{additional_days}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation_expiry') do
        with_retry do
          return false unless invitation.pending?

          new_expiry_date = invitation.expires_at + additional_days.days
          invitation.update!(expires_at: new_expiry_date)

          # Reschedule expiry job
          schedule_expiry_job(invitation)

          ReviewInvitationMailer.extended(invitation, additional_days).deliver_later

          EventPublisher.publish('review_invitation.expiry_extended', {
            invitation_id: invitation.id,
            user_id: invitation.user_id,
            old_expires_at: invitation.expires_at_was,
            new_expires_at: new_expiry_date,
            additional_days: additional_days,
            extended_at: Time.current
          })

          true
        end
      end
    end
  end

  def self.clear_expiry_cache(invitation_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:process_expired",
      "#{CACHE_KEY_PREFIX}:expire_single:#{invitation_id}",
      "#{CACHE_KEY_PREFIX}:notify:#{invitation_id}",
      "#{CACHE_KEY_PREFIX}:schedule:#{invitation_id}",
      "#{CACHE_KEY_PREFIX}:extend:#{invitation_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end