# frozen_string_literal: true

module Types
  class TagType < Types::BaseObject
    description "A product tag"

    field :id, ID, null: false
    field :name, String, null: false
  end
end

