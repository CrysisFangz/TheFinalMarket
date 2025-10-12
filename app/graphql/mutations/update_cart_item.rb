# frozen_string_literal: true

module Mutations
  class UpdateCartItem < BaseMutation
    description "Update cart item quantity"

    argument :id, ID, required: true
    argument :quantity, Integer, required: true

    field :cart_item, Types::CartItemType, null: true
    field :errors, [String], null: false

    def resolve(id:, quantity:)
      require_authentication!

      cart_item = current_user.cart.cart_items.find(id)

      if quantity <= 0
        cart_item.destroy
        { cart_item: nil, errors: [] }
      elsif cart_item.update(quantity: quantity)
        { cart_item: cart_item, errors: [] }
      else
        { cart_item: nil, errors: cart_item.errors.full_messages }
      end
    end
  end
end

