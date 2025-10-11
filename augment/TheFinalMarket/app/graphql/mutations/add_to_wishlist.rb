# frozen_string_literal: true

module Mutations
  class AddToWishlist < BaseMutation
    description "Add a product to the wishlist"

    argument :product_id, ID, required: true

    field :wishlist_item, Types::WishlistItemType, null: true
    field :errors, [String], null: false

    def resolve(product_id:)
      require_authentication!

      wishlist = current_user.wishlist || current_user.create_wishlist
      wishlist_item = wishlist.wishlist_items.create(product_id: product_id)

      if wishlist_item.persisted?
        { wishlist_item: wishlist_item, errors: [] }
      else
        { wishlist_item: nil, errors: wishlist_item.errors.full_messages }
      end
    end
  end
end

