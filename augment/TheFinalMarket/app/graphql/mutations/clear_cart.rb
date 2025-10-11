# frozen_string_literal: true

module Mutations
  class ClearCart < BaseMutation
    description "Clear all items from the cart"

    field :cart, Types::CartType, null: false
    field :errors, [String], null: false

    def resolve
      require_authentication!

      cart = current_user.cart
      cart.cart_items.destroy_all

      { cart: cart, errors: [] }
    end
  end
end

