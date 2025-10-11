# frozen_string_literal: true

module Types
  class VariantType < Types::BaseObject
    description "A product variant"

    field :id, ID, null: false
    field :name, String, null: false
    field :sku, String, null: true
    field :price, Float, null: false
    field :stock_quantity, Integer, null: false
    field :active, Boolean, null: false
    field :weight, Float, null: true
    field :dimensions, String, null: true
  end
end

