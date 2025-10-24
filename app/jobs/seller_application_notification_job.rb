class SellerApplicationNotificationJob < ApplicationJob
  queue_as :default

  def perform(application_id, action)
    application = SellerApplication.find(application_id)
    application.user.notify(actor: application.reviewed_by, action: "seller_application_#{action}", notifiable: application)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("SellerApplication with id #{application_id} not found: #{e.message}")
  rescue => e
    Rails.logger.error("Failed to send notification for seller application #{application_id}: #{e.message}")
    # Optionally, retry or handle differently
  end
end