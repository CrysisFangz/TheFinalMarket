# frozen_string_literal: true

module Types
  class WishlistItemType < Types::BaseObject
    description "An item in a wishlist"

    field :id, ID, null: false
    field :product, Types::ProductType, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    
    def product
      Loaders::RecordLoader.for(Product).load(object.product_id)
    end
  end
end

