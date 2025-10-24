class ReviewInvitationService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'review_invitation'
  CACHE_TTL = 15.minutes

  def self.expire_invitation(invitation)
    cache_key = "#{CACHE_KEY_PREFIX}:expire:#{invitation.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation') do
        with_retry do
          return unless invitation.pending?

          invitation.transaction do
            invitation.update!(status: :expired)
            ReviewInvitationExpiryService.notify_expiry(invitation)

            EventPublisher.publish('review_invitation.expired', {
              invitation_id: invitation.id,
              user_id: invitation.user_id,
              order_id: invitation.order_id,
              item_id: invitation.item_id,
              expired_at: Time.current
            })
          end

          true
        end
      end
    end
  end

  def self.complete_invitation(invitation)
    cache_key = "#{CACHE_KEY_PREFIX}:complete:#{invitation.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation') do
        with_retry do
          return unless invitation.pending?

          invitation.update!(status: :completed)

          EventPublisher.publish('review_invitation.completed', {
            invitation_id: invitation.id,
            user_id: invitation.user_id,
            order_id: invitation.order_id,
            item_id: invitation.item_id,
            completed_at: Time.current
          })

          true
        end
      end
    end
  end

  def self.create_invitation(order, user, item, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:create:#{order.id}:#{user.id}:#{item.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_invitation') do
        with_retry do
          invitation = ReviewInvitation.new(
            order: order,
            user: user,
            item: item,
            token: generate_unique_token,
            expires_at: 30.days.from_now,
            status: :pending,
            **attributes
          )

          if invitation.save
            ReviewInvitationEmailService.send_invitation_email(invitation)

            EventPublisher.publish('review_invitation.created', {
              invitation_id: invitation.id,
              user_id: invitation.user_id,
              order_id: invitation.order_id,
              item_id: invitation.item_id,
              token: invitation.token,
              expires_at: invitation.expires_at,
              created_at: invitation.created_at
            })

            invitation
          else
            false
          end
        end
      end
    end
  end

  def self.find_by_token(token)
    cache_key = "#{CACHE_KEY_PREFIX}:token:#{token}"

    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      with_circuit_breaker('review_invitation') do
        with_retry do
          ReviewInvitation.find_by(token: token)
        end
      end
    end
  end

  def self.get_active_invitations(user_id)
    cache_key = "#{CACHE_KEY_PREFIX}:active:#{user_id}"

    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      with_circuit_breaker('review_invitation') do
        with_retry do
          ReviewInvitation.active.where(user_id: user_id).includes(:order, :item).to_a
        end
      end
    end
  end

  def self.get_pending_count(user_id)
    cache_key = "#{CACHE_KEY_PREFIX}:pending_count:#{user_id}"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      with_circuit_breaker('review_invitation') do
        with_retry do
          ReviewInvitation.pending.where(user_id: user_id).count
        end
      end
    end
  end

  private

  def self.generate_unique_token
    loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless ReviewInvitation.exists?(token: token)
    end
  end

  def self.clear_invitation_cache(invitation_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:expire:#{invitation_id}",
      "#{CACHE_KEY_PREFIX}:complete:#{invitation_id}",
      "#{CACHE_KEY_PREFIX}:create:#{invitation_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end