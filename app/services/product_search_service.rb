# frozen_string_literal: true

class ProductSearchService
  def self.search(query: nil, filters: {}, page: 1, per_page: 20)
    cache_key = "product_search:#{query}:#{filters.hash}:#{page}:#{per_page}"
    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      search_definition = {
        query: {
          bool: {
            must: query.present? ? [{ multi_match: { query: query, fields: [:name, :description, :tags] } }] : [],
            filter: filters.map { |k, v| { term: { k => v } } }
          }
        },
        size: per_page,
        from: (page - 1) * per_page
      }
      Product.__elasticsearch__.search(search_definition)
    end
  end
end