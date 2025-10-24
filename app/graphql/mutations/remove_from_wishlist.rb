# frozen_string_literal: true

module Mutations
  class RemoveFromWishlist < BaseMutation
    description "Remove a product from the wishlist"

    argument :product_id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [String], null: false

    def resolve(product_id:)
      require_authentication!

      product = Product.find(product_id)
      service = WishlistService.new
      result = service.remove_product(current_user, product)

      if result.success?
        { success: true, errors: [] }
      else
        { success: false, errors: [result.failure.message] }
      end
    end
  end
end

