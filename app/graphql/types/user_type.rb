# frozen_string_literal: true

module Types
  class UserType < Types::BaseObject
    description "A user (buyer or seller)"

    field :id, ID, null: false
    field :name, String, null: false
    field :email, String, null: false
    field :user_type, String, null: false
    field :seller_tier, String, null: true
    field :level, Integer, null: false
    field :points, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end

