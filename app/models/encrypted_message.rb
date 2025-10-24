class EncryptedMessage < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :sender, class_name: 'User'
  belongs_to :recipient, class_name: 'User'
  belongs_to :conversation, optional: true

  has_many :message_attachments, dependent: :destroy
  has_many :message_reads, dependent: :destroy

  validates :encrypted_content, presence: true

  encrypts :content
  encrypts :subject

  scope :unread, -> { where(read_at: nil) }
  scope :between_users, ->(user1, user2) {
    where(
      '(sender_id = ? AND recipient_id = ?) OR (sender_id = ? AND recipient_id = ?)',
      user1.id, user2.id, user2.id, user1.id
    )
  }
  scope :recent, -> { order(created_at: :desc) }

  # Message types
  enum message_type: {
    direct: 0,
    order_related: 1,
    support: 2,
    system: 3
  }

  # Encryption methods
  ENCRYPTION_ALGORITHM = 'AES-256-GCM'.freeze

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Send encrypted message
  def self.send_encrypted(sender:, recipient:, content:, subject: nil, message_type: :direct)
    EncryptedMessageService.send_encrypted(
      sender: sender,
      recipient: recipient,
      content: content,
      subject: subject,
      message_type: message_type
    )
  end

  # Mark as read
  def mark_as_read!(user)
    MessageReadService.mark_as_read!(self, user)
  end

  # Check if read
  def read?
    Rails.cache.fetch("message:#{id}:read", expires_in: 5.minutes) do
      read_at.present?
    end
  end

  # Check if user can access message
  def accessible_by?(user)
    Rails.cache.fetch("message:#{id}:accessible_by:#{user.id}", expires_in: 10.minutes) do
      sender_id == user.id || recipient_id == user.id
    end
  end

  # Get conversation thread
  def conversation_thread
    Rails.cache.fetch("message:#{id}:conversation_thread", expires_in: 5.minutes) do
      EncryptedMessage.between_users(sender, recipient)
                     .order(created_at: :asc)
    end
  end

  # Delete for user (soft delete)
  def delete_for_user!(user)
    MessageDeletionService.delete_for_user!(self, user)
  end

  # Report message
  def report!(reporter, reason)
    MessageReportingService.report!(self, reporter, reason)
  end

  private

  def publish_created_event
    EventPublisher.publish('encrypted_message.created', {
      message_id: id,
      sender_id: sender_id,
      recipient_id: recipient_id,
      conversation_id: conversation_id,
      message_type: message_type,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('encrypted_message.updated', {
      message_id: id,
      sender_id: sender_id,
      recipient_id: recipient_id,
      read_at: read_at,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('encrypted_message.destroyed', {
      message_id: id,
      sender_id: sender_id,
      recipient_id: recipient_id
    })
  end
end