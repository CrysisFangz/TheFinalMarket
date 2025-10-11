# app/models/push_subscription.rb
class PushSubscription < ApplicationRecord
  belongs_to :user
  
  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, presence: true
  validates :auth_key, presence: true
  
  scope :active, -> { where(active: true) }
  scope :for_user, ->(user) { where(user: user) }
  scope :by_device_type, ->(type) { where(device_type: type) }
  
  # Send notification to this subscription
  def send_notification(title:, body:, url: nil, actions: nil)
    PushNotificationService.new.send_notification(
      self,
      title: title,
      body: body,
      url: url,
      actions: actions
    )
  rescue => e
    Rails.logger.error("Failed to send push notification: #{e.message}")
    
    # Deactivate subscription if endpoint is invalid
    if e.message.include?('410') || e.message.include?('404')
      update(active: false)
    end
    
    false
  end
end

