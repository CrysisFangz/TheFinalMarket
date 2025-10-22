class NotificationService
  # Service for managing notification operations with high efficiency and modularity

  def self.mark_as_read(notification, user)
    # Ensure the notification belongs to the user for security
    return false unless notification.recipient == user

    notification.mark_as_read!
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to mark notification as read: #{e.message}")
    false
  end

  def self.mark_all_as_read(user)
    # Optimize by using update_all to avoid loading records into memory
    count = user.notifications.unread.update_all(read_at: Time.current)
    count > 0
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Failed to mark all notifications as read: #{e.message}")
    false
  end

  def self.fetch_notifications(user, page: 1, per_page: 20)
    # Use pagination and eager loading if needed
    user.notifications.includes(:actor, :notifiable).order(created_at: :desc).page(page).per(per_page)
  end
end
