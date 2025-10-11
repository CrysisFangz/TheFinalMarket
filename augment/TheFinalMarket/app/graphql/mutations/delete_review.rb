# frozen_string_literal: true

module Mutations
  class DeleteReview < BaseMutation
    description "Delete a product review"

    argument :id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [String], null: false

    def resolve(id:)
      require_authentication!

      review = current_user.reviews.find(id)
      product_id = review.product_id

      if review.destroy
        # Clear cached ratings
        Rails.cache.delete("product:#{product_id}:average_rating")
        Rails.cache.delete("product:#{product_id}:total_reviews")

        { success: true, errors: [] }
      else
        { success: false, errors: review.errors.full_messages }
      end
    end
  end
end

