# frozen_string_literal: true

module Mutations
  class AddToWishlist < BaseMutation
    description "Add a product to the wishlist"

    argument :product_id, ID, required: true

    field :wishlist_item, Types::WishlistItemType, null: true
    field :errors, [String], null: false

    def resolve(product_id:)
      require_authentication!

      product = Product.find(product_id)
      service = WishlistService.new
      result = service.add_product(current_user, product)

      if result.success?
        { wishlist_item: result.value!, errors: [] }
      else
        { wishlist_item: nil, errors: [result.failure.message] }
      end
    end
  end
end

