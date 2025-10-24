class MessagePreviewService
  attr_reader :message

  def initialize(message)
    @message = message
  end

  def preview_text
    Rails.logger.debug("Generating preview text for message ID: #{message.id}")
    case message.message_type
    when 'text'
      message.body.truncate(100)
    when 'image'
      '📷 Image'
    when 'file'
      "📎 #{message.files.first.filename}"
    when 'system'
      message.body
    end
  end
end