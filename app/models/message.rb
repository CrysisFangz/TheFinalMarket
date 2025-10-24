class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :user
  has_many_attached :files

  validates :body, presence: true, unless: :has_attachments?
  validates :message_type, presence: true
  validates :attachments, allow_nil: true

  enum message_type: {
    text: 'text',
    image: 'image',
    file: 'file',
    system: 'system'
  }

  enum status: {
    sent: 'sent',
    delivered: 'delivered',
    read: 'read',
    failed: 'failed'
  }

  after_create_commit :broadcast_and_update
  after_update_commit :broadcast_status_change, if: :saved_change_to_status?

  def mark_as_read!(by_user)
    MessageService.new(self).mark_as_read!(by_user)
  end

  def mark_as_delivered!
    MessageService.new(self).mark_as_delivered!
  end

  def has_attachments?
    files.attached? || (attachments.present? && attachments['urls'].present?)
  end

  private

  def broadcast_message
    broadcast_append_to conversation
    broadcast_action_to conversation, action: :update_status
  end

  def update_conversation
    conversation.update(
      last_message: preview_text,
      last_message_at: created_at,
      unread_count: conversation.unread_count.to_i + (user_id != conversation.recipient_id ? 1 : 0)
    )
  end

  def broadcast_status_change
    broadcast_replace_to conversation,
                        target: "message_status_#{id}",
                        partial: "messages/status",
                        locals: { message: self }
  end

  def preview_text
    case message_type
    when 'text'
      body.truncate(100)
    when 'image'
      '📷 Image'
    when 'file'
      "📎 #{files.first.filename}"
    when 'system'
      body
    end
  end
end
