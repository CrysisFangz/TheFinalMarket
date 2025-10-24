class RewardNotificationService
  def self.notify(user:, title:, message:, resource:, data: {})
    Notification.create!(
      recipient: user,
      notifiable: resource,
      notification_type: 'event_reward',
      title: title,
      message: message,
      data: data
    )
  end
end