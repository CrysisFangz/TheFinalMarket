# frozen_string_literal: true

module Mutations
  class UpdateReview < BaseMutation
    description "Update a product review"

    argument :id, ID, required: true
    argument :rating, Integer, required: false
    argument :comment, String, required: false

    field :review, Types::ReviewType, null: true
    field :errors, [String], null: false

    def resolve(id:, rating: nil, comment: nil)
      require_authentication!

      review = current_user.reviews.find(id)
      attributes = {}
      attributes[:rating] = rating if rating
      attributes[:comment] = comment if comment

      if review.update(attributes)
        # Clear cached ratings
        Rails.cache.delete("product:#{review.product_id}:average_rating")

        { review: review, errors: [] }
      else
        { review: nil, errors: review.errors.full_messages }
      end
    end
  end
end

