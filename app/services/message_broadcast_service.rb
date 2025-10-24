class MessageBroadcastService
  attr_reader :message

  def initialize(message)
    @message = message
  end

  def broadcast_message
    Rails.logger.debug("Broadcasting message ID: #{message.id}")
    message.broadcast_append_to message.conversation
    message.broadcast_action_to message.conversation, action: :update_status
  end

  def update_conversation
    Rails.logger.debug("Updating conversation for message ID: #{message.id}")
    message.conversation.update(
      last_message: message.preview_text,
      last_message_at: message.created_at,
      unread_count: message.conversation.unread_count.to_i + (message.user_id != message.conversation.recipient_id ? 1 : 0)
    )
  end

  def broadcast_status_change
    Rails.logger.debug("Broadcasting status change for message ID: #{message.id}")
    message.broadcast_replace_to message.conversation,
                                 target: "message_status_#{message.id}",
                                 partial: "messages/status",
                                 locals: { message: message }
  end
end