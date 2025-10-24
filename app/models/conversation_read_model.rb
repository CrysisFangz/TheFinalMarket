# frozen_string_literal: true

# =============================================================================
# ConversationReadModel - CQRS Read Model for Conversations
# =============================================================================
# Optimized read model for conversation queries, separated from write operations.
# Provides fast, denormalized access to conversation data for UI and API consumption.
#
# Architecture: CQRS Read Model + Materialized View
# Performance: O(1) queries with pre-computed aggregations
# Scalability: Horizontal partitioning and caching
# Resilience: Automatic rebuild from event stream
# =============================================================================

class ConversationReadModel < ApplicationRecord
  # ==================== ASSOCIATIONS ====================
  belongs_to :conversation, class_name: 'Conversation', optional: true
  belongs_to :sender, class_name: 'User', foreign_key: :sender_id, optional: true
  belongs_to :recipient, class_name: 'User', foreign_key: :recipient_id, optional: true

  # ==================== VALIDATIONS ====================
  validates :conversation_id, presence: true, uniqueness: true
  validates :sender_id, presence: true
  validates :recipient_id, presence: true
  validates :conversation_type, inclusion: { in: %w[direct group] }
  validates :status, inclusion: { in: %w[active archived muted] }

  # ==================== SCOPES ====================
  scope :active, -> { where(status: 'active') }
  scope :archived, -> { where(status: 'archived') }
  scope :muted, -> { where(status: 'muted') }
  scope :direct, -> { where(conversation_type: 'direct') }
  scope :group, -> { where(conversation_type: 'group') }
  scope :by_user, ->(user_id) { where('sender_id = ? OR recipient_id = ?', user_id, user_id) }
  scope :recent, ->(since = 1.day.ago) { where('last_activity_at >= ?', since) }
  scope :with_unread, -> { where('unread_count > 0') }

  # ==================== INSTANCE METHODS ====================

  # Get other participant for direct conversations
  def other_participant(current_user_id)
    return unless conversation_type == 'direct'

    current_user_id == sender_id ? recipient : sender
  end

  # Check if user can access this conversation
  def accessible_by?(user_id)
    sender_id == user_id || recipient_id == user_id
  end

  # Update last activity
  def update_last_activity!(timestamp = Time.current)
    update!(last_activity_at: timestamp)
  end

  # Mark as read
  def mark_as_read!(by_user_id)
    return unless accessible_by?(by_user_id)

    update!(unread_count: 0, last_read_at: Time.current)
  end

  # Increment unread count
  def increment_unread_count!
    update!(unread_count: unread_count + 1)
  end

  # ==================== CLASS METHODS ====================

  # Rebuild all projections from event stream
  def self.rebuild_all!
    ConversationCreationEvent.find_each do |event|
      rebuild_from_event(event)
    end
  end

  # Rebuild projection from a specific event
  def self.rebuild_from_event(event)
    find_or_create_by(conversation_id: event.entity_id).tap do |projection|
      projection.update!(
        sender_id: event.data[:sender_id],
        recipient_id: event.data[:recipient_id],
        conversation_type: event.data[:conversation_type],
        participant_count: event.data[:participants].size,
        created_at: event.created_at,
        last_activity_at: event.created_at,
        status: 'active',
        unread_count: 0
      )
    end
  end

  # Find conversations for a user
  def self.for_user(user_id)
    by_user(user_id).active.includes(:sender, :recipient).order(last_activity_at: :desc)
  end

  # Search conversations by participant
  def self.search_by_participant(username)
    joins(:sender, :recipient).where(
      'users.username ILIKE ? OR recipients_conversation_read_models.username ILIKE ?',
      "%#{username}%", "%#{username}%"
    )
  end
end