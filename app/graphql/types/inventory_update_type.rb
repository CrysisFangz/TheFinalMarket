# frozen_string_literal: true

module Types
  class InventoryUpdateType < Types::BaseObject
    description "An inventory update notification"

    field :product_id, ID, null: false
    field :variant_id, ID, null: true
    field :stock_quantity, Integer, null: false
    field :available, Boolean, null: false
    field :low_stock, Boolean, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end

