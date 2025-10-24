class EncryptedMessageService
  def self.send_encrypted(sender:, recipient:, content:, subject: nil, message_type: :direct)
    message = EncryptedMessage.create!(
      sender: sender,
      recipient: recipient,
      content: content,
      subject: subject,
      message_type: message_type,
      encrypted_at: Time.current
    )

    # Send notification
    MessageNotificationJob.perform_later(message.id)

    message
  end
end