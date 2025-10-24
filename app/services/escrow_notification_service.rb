class EscrowNotificationService
  def self.notify(user:, title:, message:, resource:)
    NotificationService.notify(
      user: user,
      title: title,
      message: message,
      resource: resource
    )
  end
end