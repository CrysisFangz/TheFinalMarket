class ReviewInvitation < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :order
  belongs_to :user
  belongs_to :item
  has_one :review, dependent: :nullify

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :status, presence: true

  enum status: {
    pending: 'pending',
    completed: 'completed',
    expired: 'expired'
  }

  # Enhanced scopes with caching
  scope :active, -> { pending.where('expires_at > ?', Time.current) }
  scope :pending, -> { where(status: :pending) }
  scope :completed, -> { where(status: :completed) }
  scope :expired, -> { where(status: :expired) }

  # Caching
  after_create :clear_invitation_cache
  after_update :clear_invitation_cache
  after_destroy :clear_invitation_cache

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event
  
  def expire!
    ReviewInvitationService.expire_invitation(self)
  end

  def complete!
    ReviewInvitationService.complete_invitation(self)
  end

  def self.cached_find(id)
    Rails.cache.fetch("review_invitation:#{id}", expires_in: 30.minutes) do
      find_by(id: id)
    end
  end

  def self.cached_find_by_token(token)
    ReviewInvitationService.find_by_token(token)
  end

  def self.cached_active_for_user(user_id)
    ReviewInvitationService.get_active_invitations(user_id)
  end

  def self.cached_pending_count(user_id)
    ReviewInvitationService.get_pending_count(user_id)
  end

  def self.cached_expiring_soon(user_id, within_days = 3)
    ReviewInvitationExpiryService.get_expiring_soon(user_id, within_days)
  end

  def presenter
    @presenter ||= ReviewInvitationPresenter.new(self)
  end

  private

  def set_defaults
    self.token = generate_unique_token
    self.expires_at ||= 30.days.from_now
    self.status ||= :pending
  end

  def generate_unique_token
    loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless self.class.exists?(token: token)
    end
  end

  def trigger_post_create_operations
    ReviewInvitationEmailService.send_invitation_email(self)
    ReviewInvitationExpiryService.schedule_expiry_job(self)
  end

  def clear_invitation_cache
    ReviewInvitationService.clear_invitation_cache(id)
    ReviewInvitationExpiryService.clear_expiry_cache(id)
    ReviewInvitationEmailService.clear_email_cache(id)

    # Clear related caches
    Rails.cache.delete("review_invitation:#{id}")
    Rails.cache.delete("review_invitation:token:#{token}")
    Rails.cache.delete("review_invitations:user:#{user_id}")
    Rails.cache.delete("review_invitations:order:#{order_id}")
  end

  def publish_created_event
    EventPublisher.publish('review_invitation.created', {
      invitation_id: id,
      user_id: user_id,
      order_id: order_id,
      item_id: item_id,
      token: token,
      status: status,
      expires_at: expires_at,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('review_invitation.updated', {
      invitation_id: id,
      user_id: user_id,
      order_id: order_id,
      item_id: item_id,
      token: token,
      status: status,
      expires_at: expires_at,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('review_invitation.destroyed', {
      invitation_id: id,
      user_id: user_id,
      order_id: order_id,
      item_id: item_id,
      token: token,
      status: status
    })
  end
end