class MessageStatusService
  attr_reader :message

  def initialize(message)
    @message = message
  end

  def mark_as_read!(by_user)
    Rails.logger.info("Marking message ID: #{message.id} as read by user ID: #{by_user.id}")
    message.update!(status: :read, read_at: Time.current)
    Rails.logger.info("Message ID: #{message.id} marked as read")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error marking message ID: #{message.id} as read - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error marking message ID: #{message.id} as read - #{e.message}")
    raise
  end

  def mark_as_delivered!
    Rails.logger.info("Marking message ID: #{message.id} as delivered")
    message.update!(status: :delivered, delivered_at: Time.current)
    Rails.logger.info("Message ID: #{message.id} marked as delivered")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error marking message ID: #{message.id} as delivered - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error marking message ID: #{message.id} as delivered - #{e.message}")
    raise
  end
end