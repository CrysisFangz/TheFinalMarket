class EncryptedMessage < ApplicationRecord
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
  
  # Send encrypted message
  def self.send_encrypted(sender:, recipient:, content:, subject: nil, message_type: :direct)
    message = create!(
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
  
  # Mark as read
  def mark_as_read!(user)
    return if read_at.present?
    
    update!(read_at: Time.current)
    
    message_reads.create!(
      user: user,
      read_at: Time.current
    )
  end
  
  # Check if read
  def read?
    read_at.present?
  end
  
  # Check if user can access message
  def accessible_by?(user)
    sender_id == user.id || recipient_id == user.id
  end
  
  # Get conversation thread
  def conversation_thread
    EncryptedMessage.between_users(sender, recipient)
                   .order(created_at: :asc)
  end
  
  # Delete for user (soft delete)
  def delete_for_user!(user)
    if user == sender
      update!(deleted_by_sender: true)
    elsif user == recipient
      update!(deleted_by_recipient: true)
    end
    
    # Permanently delete if both users deleted
    destroy if deleted_by_sender? && deleted_by_recipient?
  end
  
  # Report message
  def report!(reporter, reason)
    MessageReport.create!(
      message: self,
      reporter: reporter,
      reason: reason,
      reported_at: Time.current
    )
  end
end

