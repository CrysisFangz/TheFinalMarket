# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    description "The query root of this schema"

    # Product queries
    field :product, Types::ProductType, null: true do
      description "Find a product by ID"
      argument :id, ID, required: true
    end

    def product(id:)
      Product.find(id)
    end

    field :products, Types::ProductType.connection_type, null: false do
      description "List all products with pagination"
      argument :first, Integer, required: false, default_value: 20
      argument :after, String, required: false
      argument :category_id, ID, required: false
      argument :tag_id, ID, required: false
      argument :min_price, Float, required: false
      argument :max_price, Float, required: false
      argument :sort_by, String, required: false, default_value: "created_at"
      argument :sort_direction, String, required: false, default_value: "desc"
    end

    def products(first:, after: nil, category_id: nil, tag_id: nil, min_price: nil, max_price: nil, sort_by: "created_at", sort_direction: "desc")
      scope = Product.all
      
      # Apply filters
      scope = scope.joins(:product_categories).where(product_categories: { category_id: category_id }) if category_id
      scope = scope.joins(:product_tags).where(product_tags: { tag_id: tag_id }) if tag_id
      scope = scope.where("price >= ?", min_price) if min_price
      scope = scope.where("price <= ?", max_price) if max_price
      
      # Apply sorting
      scope = scope.order("#{sort_by} #{sort_direction}")
      
      scope
    end

    field :search_products, Types::ProductType.connection_type, null: false do
      description "Search products by query"
      argument :query, String, required: true
      argument :first, Integer, required: false, default_value: 20
      argument :after, String, required: false
    end

    def search_products(query:, first: 20, after: nil)
      # Use Elasticsearch for fast search
      results = Product.search(query)
      Product.where(id: results.records.map(&:id))
    end

    # Category queries
    field :categories, [Types::CategoryType], null: false do
      description "List all categories"
    end

    def categories
      Rails.cache.fetch("categories:all", expires_in: 1.hour) do
        Category.all.to_a
      end
    end

    # User queries
    field :current_user, Types::UserType, null: true do
      description "Get the currently authenticated user"
    end

    def current_user
      context[:current_user]
    end

    # Cart queries
    field :cart, Types::CartType, null: true do
      description "Get the current user's cart"
    end

    def cart
      context[:current_user]&.cart
    end
  end
end

