# frozen_string_literal: true

class MessageService
  def initialize(message)
    @message = message
  end

  def broadcast_message
    @message.broadcast_append_to @message.conversation
    @message.broadcast_action_to @message.conversation, action: :update_status
  rescue StandardError => e
    Rails.logger.error("Error broadcasting message: #{e.message}")
  end

  def update_conversation
    @message.conversation.update(
      last_message: @message.preview_text,
      last_message_at: @message.created_at,
      unread_count: @message.conversation.unread_count.to_i + (@message.user_id != @message.conversation.recipient_id ? 1 : 0)
    )
  rescue StandardError => e
    Rails.logger.error("Error updating conversation: #{e.message}")
  end

  def broadcast_status_change
    @message.broadcast_replace_to @message.conversation,
                                  target: "message_status_#{@message.id}",
                                  partial: "messages/status",
                                  locals: { message: @message }
  rescue StandardError => e
    Rails.logger.error("Error broadcasting status change: #{e.message}")
  end

  def mark_as_read!(by_user)
    return if by_user == @message.user || @message.read?

    @message.update(status: :read, read_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("Error marking message as read: #{e.message}")
  end

  def mark_as_delivered!
    @message.update(status: :delivered) if @message.sent?
  rescue StandardError => e
    Rails.logger.error("Error marking message as delivered: #{e.message}")
  end

  private

  def preview_text
    case @message.message_type
    when 'text'
      @message.body.truncate(100)
    when 'image'
      '📷 Image'
    when 'file'
      "📎 #{@message.files.first.filename}"
    when 'system'
      @message.body
    end
  end
end