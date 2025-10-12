# frozen_string_literal: true

module Types
  class CategoryType < Types::BaseObject
    description "A product category"

    field :id, ID, null: false
    field :name, String, null: false
    field :slug, String, null: false
    field :description, String, null: true
    field :products_count, Integer, null: false
    
    def products_count
      Rails.cache.fetch("category:#{object.id}:products_count", expires_in: 1.hour) do
        object.products.count
      end
    end
  end
end

