# frozen_string_literal: true

module Types
  class CartItemType < Types::BaseObject
    description "An item in a shopping cart"

    field :id, ID, null: false
    field :product, Types::ProductType, null: false
    field :variant, Types::VariantType, null: true
    field :quantity, Integer, null: false
    field :unit_price, Float, null: false
    field :total_price, Float, null: false
    
    def product
      Loaders::RecordLoader.for(Product).load(object.product_id)
    end
    
    def variant
      Loaders::RecordLoader.for(Variant).load(object.variant_id) if object.variant_id
    end
    
    def unit_price
      object.product.price
    end
    
    def total_price
      object.quantity * unit_price
    end
  end
end

