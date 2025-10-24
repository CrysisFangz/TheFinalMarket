class ChallengeNotificationService
  def self.notify(user:, title:, message:, resource:, data: {})
    Notification.create!(
      recipient: user,
      notifiable: resource,
      notification_type: 'challenge_completed',
      title: title,
      message: message,
      data: data
    )
  end
end