# frozen_string_literal: true

require 'test_helper'

class ConversationCreationEventTest < ActiveSupport::TestCase
  include EventSourcing::TestHelpers

  setup do
    @user1 = users(:one)
    @user2 = users(:two)
    @conversation = conversations(:one)
  end

  test 'should create valid event' do
    event = ConversationCreationEvent.new(
      entity_id: @conversation.id,
      entity_type: 'Conversation',
      event_type: 'conversation_created',
      data: {
        participants: [@user1.id, @user2.id],
        conversation_type: 'direct',
        sender_id: @user1.id,
        recipient_id: @user2.id
      },
      creator_id: @user1.id,
      sequence_number: 1
    )

    assert event.valid?
    assert event.save
  end

  test 'should validate required fields' do
    event = ConversationCreationEvent.new

    assert_not event.valid?
    assert_includes event.errors[:event_type], "can't be blank"
    assert_includes event.errors[:data], "can't be blank"
  end

  test 'should validate conversation participants' do
    event = ConversationCreationEvent.new(
      entity_id: @conversation.id,
      event_type: 'conversation_created',
      data: {
        participants: [@user1.id], # Only one participant
        conversation_type: 'direct'
      },
      creator_id: @user1.id
    )

    assert_not event.valid?
    assert_includes event.errors[:data], "conversation must have at least 2 participants"
  end

  test 'should apply event to conversation' do
    event = ConversationCreationEvent.new(
      entity_id: @conversation.id,
      event_type: 'conversation_created',
      data: {
        participants: [@user1.id, @user2.id],
        conversation_type: 'direct',
        sender_id: @user1.id,
        recipient_id: @user2.id
      },
      created_at: Time.current
    )

    conversation = Conversation.new
    event.apply_to(conversation)

    assert_equal @user1.id, conversation.sender_id
    assert_equal @user2.id, conversation.recipient_id
    assert_equal 'direct', conversation.conversation_type
  end

  test 'should trigger event handlers on create' do
    event = ConversationCreationEvent.new(
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

    # Mock the event bus
    EventSourcing::EventBus.expects(:publish).with('conversation_created', event)

    event.save
  end

  test 'should update conversation projection on create' do
    event = ConversationCreationEvent.new(
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

    # Mock the projection update
    ConversationReadModel.expects(:find_or_create_by).with(conversation_id: @conversation.id).returns(mock)

    event.save
  end

  test 'should invalidate caches on create' do
    event = ConversationCreationEvent.new(
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

    # Mock cache invalidation
    CacheStore::Optimized.any_instance.expects(:invalidate_user_conversations_cache).twice
    CacheStore::Optimized.any_instance.expects(:invalidate_conversation_cache).with(@conversation.id)

    event.save
  end
end