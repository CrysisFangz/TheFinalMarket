# frozen_string_literal: true

module Mutations
  class CreateReview < BaseMutation
    description "Create a product review"

    argument :product_id, ID, required: true
    argument :rating, Integer, required: true
    argument :comment, String, required: false

    field :review, Types::ReviewType, null: true
    field :errors, [String], null: false

    def resolve(product_id:, rating:, comment: nil)
      require_authentication!

      product = Product.find(product_id)
      review = product.reviews.build(
        user: current_user,
        rating: rating,
        comment: comment
      )

      if review.save
        # Clear cached ratings
        Rails.cache.delete("product:#{product_id}:average_rating")
        Rails.cache.delete("product:#{product_id}:total_reviews")

        { review: review, errors: [] }
      else
        { review: nil, errors: review.errors.full_messages }
      end
    end
  end
end

