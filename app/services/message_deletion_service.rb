class MessageDeletionService
  def self.delete_for_user!(message, user)
    if user == message.sender
      message.update!(deleted_by_sender: true)
    elsif user == message.recipient
      message.update!(deleted_by_recipient: true)
    end

    # Permanently delete if both users deleted
    message.destroy if message.deleted_by_sender? && message.deleted_by_recipient?
  end
end