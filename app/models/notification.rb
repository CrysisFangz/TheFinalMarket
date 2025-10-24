class Notification < ApplicationRecord
  belongs_to :recipient, polymorphic: true
  belongs_to :actor, polymorphic: true
  belongs_to :notifiable, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc).limit(10) }

  after_create_commit :broadcast_to_recipient

  def mark_as_read!
    update!(read_at: Time.current)
  end

  # Note: mark_as_read! is simple, kept in model

  private

  def broadcast_to_recipient
    broadcast_service.broadcast_to_recipient
  end

  def broadcast_service
    @broadcast_service ||= NotificationBroadcastService.new(self)
  end
end
