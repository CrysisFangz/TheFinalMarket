class EncryptedMessagePresenter
  def initialize(message)
    @message = message
  end

  def as_json(options = {})
    {
      id: @message.id,
      sender_id: @message.sender_id,
      recipient_id: @message.recipient_id,
      conversation_id: @message.conversation_id,
      subject: @message.subject,
      message_type: @message.message_type,
      read_at: @message.read_at,
      encrypted_at: @message.encrypted_at,
      deleted_by_sender: @message.deleted_by_sender?,
      deleted_by_recipient: @message.deleted_by_recipient?,
      created_at: @message.created_at,
      updated_at: @message.updated_at,
      read: @message.read?,
      accessible_by: @message.accessible_by?(options[:current_user]),
      attachments_count: @message.message_attachments.count,
      reads_count: @message.message_reads.count
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end