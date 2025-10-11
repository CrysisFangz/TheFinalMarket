# frozen_string_literal: true

module Types
  class ReviewType < Types::BaseObject
    description "A product review"

    field :id, ID, null: false
    field :rating, Integer, null: false
    field :comment, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :reviewer, Types::UserType, null: false
    field :helpful_count, Integer, null: false
    
    def reviewer
      Loaders::RecordLoader.for(User).load(object.user_id)
    end
    
    def helpful_count
      object.helpful_votes.count
    end
  end
end

