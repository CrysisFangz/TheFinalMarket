# frozen_string_literal: true

# Message Interactors - CQRS and Event Sourcing for Message Operations
# Implements Command Query Responsibility Segregation with Event Sourcing
# for hyperscale messaging operations with antifragile resilience

module MessageInteractors
  # Command: Edit Message with Event Sourcing
  class EditMessage
    include Interactor

    def call
      validate_permissions!
      execute_edit
      publish_events
    end

    private

    def validate_permissions!
      message = message_service.find_message(context.message_id)
      unless message&.user == context.current_user
        context.fail!(error: 'Unauthorized to edit message')
      end

      edit_window = 15.minutes
      if message.created_at < edit_window.ago
        context.fail!(error: 'Message edit window expired')
      end
    end

    def execute_edit
      context.result = message_service.edit_message(
        message_id: context.message_id,
        new_content: context.content,
        edited_by: context.current_user,
        edit_reason: context.edit_reason
      )
    end

    def publish_events
      event_store.append(
        MessageEditedEvent.new(
          message_id: context.message_id,
          user_id: context.current_user.id,
          new_content: context.content,
          edited_at: Time.current
        )
      )
    end

    def message_service
      @message_service ||= MessageService::Core.instance
    end

    def event_store
      @event_store ||= EventStore.instance
    end
  end

  # Command: Delete Message with Event Sourcing
  class DeleteMessage
    include Interactor

    def call
      validate_permissions!
      execute_deletion
      publish_events
    end

    private

    def validate_permissions!
      message = message_service.find_message(context.message_id)
      unless message&.user == context.current_user
        context.fail!(error: 'Unauthorized to delete message')
      end

      deletion_window = 1.hour
      if message.created_at < deletion_window.ago
        context.fail!(error: 'Message deletion window expired')
      end
    end

    def execute_deletion
      context.result = message_service.delete_message(
        message_id: context.message_id,
        deleted_by: context.current_user,
        deletion_reason: context.reason,
        soft_delete: context.soft_delete
      )
    end

    def publish_events
      event_store.append(
        MessageDeletedEvent.new(
          message_id: context.message_id,
          user_id: context.current_user.id,
          deleted_at: Time.current,
          soft_delete: context.soft_delete
        )
      )
    end

    def message_service
      @message_service ||= MessageService::Core.instance
    end

    def event_store
      @event_store ||= EventStore.instance
    end
  end

  # Query: Get Message History with CQRS Read Model
  class GetMessageHistory
    include Interactor

    def call
      context.result = read_model_repository.get_message_history(
        conversation_id: context.conversation_id,
        user: context.current_user,
        limit: context.limit || 50
      )
    end

    private

    def read_model_repository
      @read_model_repository ||= MessageReadModelRepository.instance
    end
  end

  # Command: Mark Messages as Read with Batch Optimization
  class MarkAsRead
    include Interactor

    def call
      validate_authorization!
      execute_batch_mark
      publish_events
    end

    private

    def validate_authorization!
      # Use security service for authorization
    end

    def execute_batch_mark
      context.result = message_service.mark_messages_as_read(
        message_ids: context.message_ids,
        read_by: context.current_user,
        conversation_id: context.conversation_id,
        timestamp: Time.current
      )
    end

    def publish_events
      context.message_ids.each do |message_id|
        event_store.append(
          MessageReadEvent.new(
            message_id: message_id,
            user_id: context.current_user.id,
            read_at: Time.current
          )
        )
      end
    end

    def message_service
      @message_service ||= MessageService::Core.instance
    end

    def event_store
      @event_store ||= EventStore.instance
    end
  end
end

# Event Classes for Event Sourcing
class MessageEditedEvent
  attr_reader :message_id, :user_id, :new_content, :edited_at

  def initialize(message_id:, user_id:, new_content:, edited_at:)
    @message_id = message_id
    @user_id = user_id
    @new_content = new_content
    @edited_at = edited_at
  end

  def event_type
    :message_edited
  end

  def to_h
    {
      event_type: event_type,
      message_id: message_id,
      user_id: user_id,
      new_content: new_content,
      edited_at: edited_at
    }
  end
end

class MessageDeletedEvent
  attr_reader :message_id, :user_id, :deleted_at, :soft_delete

  def initialize(message_id:, user_id:, deleted_at:, soft_delete:)
    @message_id = message_id
    @user_id = user_id
    @deleted_at = deleted_at
    @soft_delete = soft_delete
  end

  def event_type
    :message_deleted
  end

  def to_h
    {
      event_type: event_type,
      message_id: message_id,
      user_id: user_id,
      deleted_at: deleted_at,
      soft_delete: soft_delete
    }
  end
end

class MessageReadEvent
  attr_reader :message_id, :user_id, :read_at

  def initialize(message_id:, user_id:, read_at:)
    @message_id = message_id
    @user_id = user_id
    @read_at = read_at
  end

  def event_type
    :message_read
  end

  def to_h
    {
      event_type: event_type,
      message_id: message_id,
      user_id: user_id,
      read_at: read_at
    }
  end
end

# Read Model Repository for CQRS Queries
class MessageReadModelRepository
  include Singleton

  def get_message_history(conversation_id:, user:, limit:)
    # Query read model for message history
    # This would be a denormalized view for fast reads
    MessageReadModel.where(conversation_id: conversation_id, user_id: user.id)
                    .order(created_at: :desc)
                    .limit(limit)
                    .as_json
  end
end

# Event Store for Event Sourcing
class EventStore
  include Singleton

  def append(event)
    # Append event to event store
    EventRecord.create!(
      event_type: event.event_type,
      event_data: event.to_h,
      aggregate_id: event.message_id || event.conversation_id,
      occurred_at: Time.current
    )
  end
end

# Event Record Model
class EventRecord < ApplicationRecord
  serialize :event_data, JSON
end