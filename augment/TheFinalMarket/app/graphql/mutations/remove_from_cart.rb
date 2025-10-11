# frozen_string_literal: true

module Mutations
  class RemoveFromCart < BaseMutation
    description "Remove an item from the cart"

    argument :id, ID, required: true

    field :cart, Types::CartType, null: false
    field :errors, [String], null: false

    def resolve(id:)
      require_authentication!

      cart_item = current_user.cart.cart_items.find(id)
      cart = current_user.cart

      if cart_item.destroy
        { cart: cart, errors: [] }
      else
        { cart: cart, errors: cart_item.errors.full_messages }
      end
    end
  end
end

