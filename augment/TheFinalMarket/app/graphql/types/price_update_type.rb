# frozen_string_literal: true

module Types
  class PriceUpdateType < Types::BaseObject
    description "A price update notification"

    field :product_id, ID, null: false
    field :old_price, Float, null: false
    field :new_price, Float, null: false
    field :discount_percentage, Float, null: true
    field :reason, String, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end

