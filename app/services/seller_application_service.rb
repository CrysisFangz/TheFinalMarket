class SellerApplicationService
  def initialize(application)
    @application = application
  end

  def process_creation
    update_user_status_to_pending
  end

  def process_status_change
    case @application.status
    when 'approved'
      approve_application
    when 'rejected'
      reject_application
    end
  end

  private

  def update_user_status_to_pending
    @application.user.update_columns(seller_status: 'pending_approval')
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("Failed to update user status for seller application #{@application.id}: #{e.message}")
    raise
  end

  def approve_application
    @application.user.update_columns(seller_status: 'pending_bond')
    SellerApplicationNotificationJob.perform_later(@application.id, 'approved')
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("Failed to approve seller application #{@application.id}: #{e.message}")
    raise
  end

  def reject_application
    @application.user.update_columns(seller_status: 'rejected', seller_rejection_reason: @application.rejection_reason)
    SellerApplicationNotificationJob.perform_later(@application.id, 'rejected')
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("Failed to reject seller application #{@application.id}: #{e.message}")
    raise
  end
end