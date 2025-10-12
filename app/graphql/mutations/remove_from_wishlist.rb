# frozen_string_literal: true

module Mutations
  class RemoveFromWishlist < BaseMutation
    description "Remove a product from the wishlist"

    argument :product_id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [String], null: false

    def resolve(product_id:)
      require_authentication!

      wishlist_item = current_user.wishlist.wishlist_items.find_by(product_id: product_id)

      if wishlist_item&.destroy
        { success: true, errors: [] }
      else
        { success: false, errors: ["Wishlist item not found"] }
      end
    end
  end
end

