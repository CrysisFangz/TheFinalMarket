# frozen_string_literal: true

module Types
  class CartType < Types::BaseObject
    description "A shopping cart"

    field :id, ID, null: false
    field :items, [Types::CartItemType], null: false
    field :total_items, Integer, null: false
    field :subtotal, Float, null: false
    field :tax, Float, null: false
    field :total, Float, null: false
    
    def items
      Loaders::AssociationLoader.for(Cart, :cart_items).load(object)
    end
    
    def total_items
      object.cart_items.sum(:quantity)
    end
    
    def subtotal
      object.cart_items.sum { |item| item.quantity * item.product.price }
    end
    
    def tax
      subtotal * 0.1 # 10% tax
    end
    
    def total
      subtotal + tax
    end
  end
end

