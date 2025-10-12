# frozen_string_literal: true

module Mutations
  class AddToCart < BaseMutation
    description "Add a product to the cart"

    argument :product_id, ID, required: true
    argument :variant_id, ID, required: false
    argument :quantity, Integer, required: false, default_value: 1

    field :cart, Types::CartType, null: false
    field :cart_item, Types::CartItemType, null: false
    field :errors, [String], null: false

    def resolve(product_id:, variant_id: nil, quantity: 1)
      require_authentication!

      product = Product.find(product_id)
      cart = current_user.cart || current_user.create_cart

      cart_item = cart.cart_items.find_or_initialize_by(
        product_id: product_id,
        variant_id: variant_id
      )

      cart_item.quantity = (cart_item.quantity || 0) + quantity

      if cart_item.save
        # Broadcast cart update via WebSocket
        CartChannel.broadcast_to(current_user, {
          type: 'item_added',
          cart_item: cart_item,
          total_items: cart.cart_items.sum(:quantity)
        })

        {
          cart: cart,
          cart_item: cart_item,
          errors: []
        }
      else
        {
          cart: cart,
          cart_item: nil,
          errors: cart_item.errors.full_messages
        }
      end
    end
  end
end

