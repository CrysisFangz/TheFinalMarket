# frozen_string_literal: true

module Loaders
  class RecordLoader < GraphQL::Batch::Loader
    def initialize(model)
      super()
      @model = model
    end

    def perform(ids)
      records = @model.where(id: ids).index_by(&:id)
      ids.each { |id| fulfill(id, records[id]) }
    end
  end
end

