# frozen_string_literal: true

module Types
  class SubscriptionType < Types::BaseObject
    description "The subscription root of this schema"

    field :product_updated, Types::ProductType, null: false do
      description "Subscribe to product updates"
      argument :id, ID, required: true
    end

    def product_updated(id:)
      # This will be triggered by ProductChannel
    end

    field :inventory_changed, Types::InventoryUpdateType, null: false do
      description "Subscribe to inventory changes"
      argument :product_id, ID, required: true
    end

    def inventory_changed(product_id:)
      # This will be triggered by InventoryChannel
    end

    field :price_changed, Types::PriceUpdateType, null: false do
      description "Subscribe to price changes"
      argument :product_id, ID, required: true
    end

    def price_changed(product_id:)
      # This will be triggered by PricingChannel
    end
  end
end

