class NotificationBroadcastService
  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  def broadcast_to_recipient
    Rails.logger.debug("Broadcasting notification ID: #{notification.id} to recipient ID: #{notification.recipient.id}")

    begin
      notification.broadcast_prepend_later_to "notifications_#{notification.recipient.id}",
        partial: "notifications/notification",
        locals: { notification: notification }
      Rails.logger.info("Successfully queued broadcast for notification ID: #{notification.id}")
    rescue => e
      Rails.logger.error("Failed to broadcast notification ID: #{notification.id}. Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      # Optionally, could enqueue a retry job or handle failure differently
    end
  end
end