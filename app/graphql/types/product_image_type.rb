# frozen_string_literal: true

module Types
  class ProductImageType < Types::BaseObject
    description "A product image with optimized formats"

    field :id, ID, null: false
    field :url, String, null: false
    field :thumbnail, String, null: false
    field :small, String, null: false
    field :medium, String, null: false
    field :large, String, null: false
    field :webp, String, null: false
    field :webp_thumbnail, String, null: false
    field :blur_placeholder, String, null: false
    field :position, Integer, null: false
    field :alt_text, String, null: true
    
    def url
      object.image_url(:large)
    end
    
    def thumbnail
      object.image_url(:thumbnail)
    end
    
    def small
      object.image_url(:small)
    end
    
    def medium
      object.image_url(:medium)
    end
    
    def large
      object.image_url(:large)
    end
    
    def webp
      object.image_url(:large, format: :webp)
    end
    
    def webp_thumbnail
      object.image_url(:thumbnail, format: :webp)
    end
    
    def blur_placeholder
      object.blur_placeholder_data_url
    end
  end
end

