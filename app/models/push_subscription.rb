# frozen_string_literal: true

# PushSubscription model refactored for resilience and performance.
# Manages user push notification subscriptions with comprehensive error handling.
class PushSubscription < ApplicationRecord
  belongs_to :user

  # Enhanced validations with custom messages
  validates :endpoint, presence: true, uniqueness: true, format: { with: /\Ahttps?:\/\//, message: "must be a valid URL" }
  validates :p256dh_key, presence: true, length: { is: 88 }
  validates :auth_key, presence: true, length: { is: 24 }
  validates :user_agent, length: { maximum: 500 }, allow_blank: true
  validates :ip_address, format: { with: /\A(\d{1,3}\.){3}\d{1,3}\z/, message: "must be a valid IP address" }, allow_blank: true

  # Enhanced scopes with performance optimization
  scope :active, -> { where(active: true) }
  scope :for_user, ->(user) { where(user: user) }
  scope :by_device_type, ->(type) { where(device_type: type) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_user, -> { includes(:user) }

  # Event-driven: Publish events on subscription lifecycle
  after_create :publish_subscription_created_event
  after_update :publish_subscription_updated_event, if: :saved_change_to_active?
  after_destroy :publish_subscription_destroyed_event

  # Send notification with enhanced error handling
  def send_notification(title:, body:, url: nil, actions: nil)
    PushNotificationService.new.send_notification(
      self,
      title: title,
      body: body,
      url: url,
      actions: actions
    )
  rescue => e
    Rails.logger.error("Failed to send push notification to subscription #{id}: #{e.message}")

    # Deactivate subscription if endpoint is invalid
    if endpoint_error?(e)
      deactivate_with_reason('invalid_endpoint')
    end

    false
  end

  # Check if subscription is valid and active
  def valid_and_active?
    active? && endpoint.present? && p256dh_key.present? && auth_key.present?
  end

  # Get subscription age in days
  def age_in_days
    return 0 unless created_at
    ((Time.current - created_at) / 1.day).to_i
  end

  private

  def endpoint_error?(error)
    error.message.include?('410') || error.message.include?('404') || error.message.include?('400')
  end

  def deactivate_with_reason(reason)
    update!(active: false, deactivated_reason: reason, deactivated_at: Time.current)
  end

  def publish_subscription_created_event
    Rails.logger.info("Push subscription created: ID=#{id}, User=#{user_id}, Device=#{device_type}")
    # In a full event system: EventPublisher.publish('push_subscription_created', self.attributes)
  end

  def publish_subscription_updated_event
    Rails.logger.info("Push subscription updated: ID=#{id}, Active=#{active}")
    # In a full event system: EventPublisher.publish('push_subscription_updated', self.attributes)
  end

  def publish_subscription_destroyed_event
    Rails.logger.info("Push subscription destroyed: ID=#{id}, User=#{user_id}")
    # In a full event system: EventPublisher.publish('push_subscription_destroyed', self.attributes)
  end
end

