# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message, type: :model do
  let(:user) { create(:user) }
  let(:conversation) { create(:conversation, user: user) }
  let(:message) { create(:message, user: user, conversation: conversation) }

  describe '#mark_as_read!' do
    it 'delegates to MessageService' do
      expect(MessageService).to receive(:new).with(message).and_call_original
      message.mark_as_read!(user)
    end
  end

  describe '#mark_as_delivered!' do
    it 'delegates to MessageService' do
      expect(MessageService).to receive(:new).with(message).and_call_original
      message.mark_as_delivered!
    end
  end

  describe 'validations' do
    it 'validates presence of message_type' do
      message.message_type = nil
      expect(message).not_to be_valid
    end

    it 'validates body presence unless has attachments' do
      message.body = nil
      expect(message).not_to be_valid
    end
  end

  describe 'enums' do
    it 'has correct message_type enum' do
      expect(message.message_type).to eq('text')
    end

    it 'has correct status enum' do
      expect(message.status).to eq('sent')
    end
  end
end