class MessageReadService
  def self.mark_as_read!(message, user)
    return if message.read_at.present?

    message.update!(read_at: Time.current)

    message.message_reads.create!(
      user: user,
      read_at: Time.current
    )
  end
end