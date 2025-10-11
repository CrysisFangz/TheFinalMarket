# frozen_string_literal: true

module Types
  class ProductType < Types::BaseObject
    description "A product in the marketplace"

    field :id, ID, null: false
    field :name, String, null: false
    field :description, String, null: true
    field :price, Float, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    
    field :images, [Types::ProductImageType], null: false
    field :variants, [Types::VariantType], null: false
    field :categories, [Types::CategoryType], null: false
    field :tags, [Types::TagType], null: false
    field :seller, Types::UserType, null: false
    
    field :reviews, Types::ReviewType.connection_type, null: false do
      argument :first, Integer, required: false
      argument :after, String, required: false
    end
    
    field :average_rating, Float, null: true
    field :total_reviews, Integer, null: false
    field :total_stock, Integer, null: false
    field :min_price, Float, null: true
    field :max_price, Float, null: true
    
    # Resolve images with DataLoader to prevent N+1
    def images
      Loaders::AssociationLoader.for(Product, :product_images).load(object)
    end
    
    # Resolve variants with DataLoader
    def variants
      Loaders::AssociationLoader.for(Product, :variants).load(object)
    end
    
    # Resolve categories with DataLoader
    def categories
      Loaders::AssociationLoader.for(Product, :categories).load(object)
    end
    
    # Resolve tags with DataLoader
    def tags
      Loaders::AssociationLoader.for(Product, :tags).load(object)
    end
    
    # Resolve seller with DataLoader
    def seller
      Loaders::RecordLoader.for(User).load(object.user_id)
    end
    
    # Cached average rating
    def average_rating
      Rails.cache.fetch("product:#{object.id}:average_rating", expires_in: 1.hour) do
        object.reviews.average(:rating)&.round(2)
      end
    end
    
    # Cached total reviews
    def total_reviews
      Rails.cache.fetch("product:#{object.id}:total_reviews", expires_in: 1.hour) do
        object.reviews.count
      end
    end
  end
end

