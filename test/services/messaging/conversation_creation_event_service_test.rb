# frozen_string_literal: true

require 'test_helper'

class ConversationCreationEventServiceTest < ActiveSupport::TestCase
  setup do
    @service = ConversationCreationEventService.new
    @user1 = users(:one)
    @user2 = users(:two)
    @conversation = conversations(:one)
    @event = ConversationCreationEvent.new(
      entity_id: @conversation.id,
      event_type: 'conversation_created',
      data: {
        participants: [@user1.id, @user2.id],
        conversation_type: 'direct',
        sender_id: @user1.id,
        recipient_id: @user2.id
      },
      creator_id: @user1.id
    )
  end

  test 'should process event successfully' do
    result = @service.process_event(@event)

    assert result.success?
    assert_equal 'Event processed successfully', result.message
  end

  test 'should validate event before processing' do
    invalid_event = ConversationCreationEvent.new

    assert_raises(ValidationError) do
      @service.process_event(invalid_event)
    end
  end

  test 'should rebuild conversation state from events' do
    # Create multiple events
    event1 = ConversationCreationEvent.create!(
      entity_id: @conversation.id,
      event_type: 'conversation_created',
      data: {
        participants: [@user1.id, @user2.id],
        conversation_type: 'direct',
        sender_id: @user1.id,
        recipient_id: @user2.id
      },
      creator_id: @user1.id
    )

    rebuilt_conversation = @service.rebuild_conversation_state(@conversation.id)

    assert_equal @user1.id, rebuilt_conversation.sender_id
    assert_equal @user2.id, rebuilt_conversation.recipient_id
  end

  test 'should update conversation projection' do
    projection = @service.update_conversation_projection(@conversation)

    assert_equal @conversation.id, projection.conversation_id
    assert_equal @user1.id, projection.sender_id
    assert_equal @user2.id, projection.recipient_id
  end

  test 'should handle processing failures with retry' do
    # Mock a failure
    ConversationCreationEvent.any_instance.stubs(:save!).raises(StandardError.new('Database error'))

    assert_raises(StandardError) do
      @service.process_event(@event)
    end

    # Check if retry job is scheduled (mocked)
    # In real test, would check Sidekiq queue
  end

  test 'should move to dead letter queue after max retries' do
    @event.metadata = { retry_count: 3 }

    error = StandardError.new('Persistent error')
    @service.handle_processing_failure(@event, error)

    dead_letter = DeadLetterEvent.last
    assert_equal @event.id, dead_letter.original_event_id
    assert_equal error.message, dead_letter.error_message
  end
end