class NotificationsController < ApplicationController
  before_action :require_login
  before_action :set_notification, only: [:mark_as_read]

  # Index action: Fetch paginated notifications using the service
  def index
    @notifications = NotificationService.fetch_notifications(current_user, page: params[:page])
  end

  # Mark a single notification as read
  def mark_as_read
    success = NotificationService.mark_as_read(@notification, current_user)
    if success
      respond_to do |format|
        format.html { redirect_back(fallback_location: notifications_path) }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to notifications_path, alert: 'Unable to mark notification as read.' }
        format.turbo_stream { render turbo_stream: turbo_stream.alert('Error marking as read') }
      end
    end
  end

  # Mark all notifications as read
  def mark_all_as_read
    success = NotificationService.mark_all_as_read(current_user)
    if success
      respond_to do |format|
        format.html { redirect_back(fallback_location: notifications_path) }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("notifications_count", partial: "layouts/notifications_count") }
      end
    else
      respond_to do |format|
        format.html { redirect_to notifications_path, alert: 'Unable to mark all notifications as read.' }
        format.turbo_stream { render turbo_stream: turbo_stream.alert('Error marking all as read') }
      end
    end
  end

  private

  # Set notification with error handling
  def set_notification
    @notification = current_user.notifications.find_by(id: params[:id])
    unless @notification
      redirect_to notifications_path, alert: 'Notification not found.'
      return
    end
  end
end
