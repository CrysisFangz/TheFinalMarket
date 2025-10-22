class ConversationCreationEvent < ApplicationRecord
  belongs_to :conversation
  belongs_to :creator, class_name: 'User'
end