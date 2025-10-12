# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    description "The mutation root of this schema"

    # Cart mutations
    field :add_to_cart, mutation: Mutations::AddToCart
    field :update_cart_item, mutation: Mutations::UpdateCartItem
    field :remove_from_cart, mutation: Mutations::RemoveFromCart
    field :clear_cart, mutation: Mutations::ClearCart

    # Wishlist mutations
    field :add_to_wishlist, mutation: Mutations::AddToWishlist
    field :remove_from_wishlist, mutation: Mutations::RemoveFromWishlist

    # Review mutations
    field :create_review, mutation: Mutations::CreateReview
    field :update_review, mutation: Mutations::UpdateReview
    field :delete_review, mutation: Mutations::DeleteReview
  end
end

