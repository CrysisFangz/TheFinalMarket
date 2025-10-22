# frozen_string_literal: true

module Categories
  module Services
    module Queries
      # Query service for category read operations
      class CategoryQueries
        # @param repository [Repositories::CategoryRepository] repository instance
        # @param cache [Cache] cache instance (optional)
        def initialize(repository, cache = nil)
          @repository = repository
          @cache = cache
        end

        # Finds a category by ID with caching
        # @param id [String] category identifier
        # @return [Entities::Category, nil] the category or nil if not found
        def find_by_id(id)
          cache_key = "category:#{id}"

          cached_result = @cache&.get(cache_key)
          return cached_result if cached_result

          result = @repository.find_by_id(id)

          @cache&.set(cache_key, result, expires_in: 1.hour) if result
          result
        end

        # Gets the complete category tree with caching
        # @return [Array<Entities::Category>] all categories in tree structure
        def get_tree
          cache_key = 'category:tree'

          cached_result = @cache&.get(cache_key)
          return cached_result if cached_result

          roots = @repository.find_roots
          result = build_tree_from_roots(roots)

          @cache&.set(cache_key, result, expires_in: 30.minutes)
          result
        end

        # Finds all categories with their item counts
        # @return [Array<Hash>] categories with item counts
        def categories_with_item_counts
          # This would typically join with items table
          # For now, return categories and let caller handle item counts
          @repository.find_roots.map do |category|
            {
              category: category,
              item_count: calculate_item_count(category),
              has_children: category.can_have_children?
            }
          end
        end

        # Searches categories by name or description
        # @param search_term [String] term to search for
        # @param limit [Integer] maximum results (optional)
        # @return [Array<Entities::Category>] matching categories
        def search(search_term, limit = 50)
          return [] unless search_term&.strip&.length&.>=(2)

          # Search by name pattern
          results = @repository.find_by_name_pattern(search_term)

          # Limit results for performance
          results.first(limit)
        end

        # Gets category breadcrumb trail
        # @param category [Entities::Category] the target category
        # @return [Array<Entities::Category>] breadcrumb trail
        def get_breadcrumb_trail(category)
          return [] unless category

          ancestors = @repository.find_ancestors(category.path)
          ancestors + [category]
        end

        # Gets category suggestions for autocomplete
        # @param partial_name [String] partial category name
        # @param limit [Integer] maximum suggestions
        # @return [Array<Hash>] category suggestions with metadata
        def get_suggestions(partial_name, limit = 10)
          return [] unless partial_name&.strip&.length&.>=(2)

          matching_categories = @repository.find_by_name_pattern(partial_name)

          suggestions = matching_categories.first(limit).map do |category|
            {
              id: category.id,
              name: category.name.to_s,
              full_path: category.path.to_s,
              depth: category.depth,
              active: category.active?
            }
          end

          suggestions.sort_by { |suggestion| [suggestion[:depth], suggestion[:name]] }
        end

        # Gets popular categories based on item count
        # @param limit [Integer] maximum categories to return
        # @return [Array<Hash>] popular categories with metrics
        def get_popular_categories(limit = 10)
          # This would typically require joining with items/products
          # For now, return most recently created active categories
          active_categories = @repository.find_by_status(ValueObjects::CategoryStatus.new(:active))

          active_categories
            .sort_by { |category| category.created_at }
            .reverse
            .first(limit)
            .map do |category|
              {
                category: category,
                estimated_popularity: estimate_popularity(category),
                item_count: calculate_item_count(category)
              }
            end
        end

        # Gets category statistics
        # @return [Hash] various category statistics
        def get_statistics
          cache_key = 'category:statistics'

          cached_result = @cache&.get(cache_key)
          return cached_result if cached_result

          total_categories = @repository.count
          active_categories = @repository.find_by_status(ValueObjects::CategoryStatus.new(:active)).count
          root_categories = @repository.find_roots.count

          result = {
            total_categories: total_categories,
            active_categories: active_categories,
            inactive_categories: total_categories - active_categories,
            root_categories: root_categories,
            average_depth: calculate_average_depth,
            max_depth: calculate_max_depth,
            categories_with_items: calculate_categories_with_items
          }

          @cache&.set(cache_key, result, expires_in: 15.minutes)
          result
        end

        private

        # Builds tree structure from root categories
        # @param roots [Array<Entities::Category>] root categories
        # @return [Array<Hash>] tree structure
        def build_tree_from_roots(roots)
          roots.map do |root|
            build_category_node(root)
          end
        end

        # Builds a category node with children
        # @param category [Entities::Category] category to build node for
        # @return [Hash] category node with children
        def build_category_node(category)
          children = if category.can_have_children?
                      @repository.find_children(category.path)
                    else
                      []
                    end

          {
            category: category,
            children: children.map { |child| build_category_node(child) },
            has_children: children.any?,
            item_count: calculate_item_count(category)
          }
        end

        # Calculates item count for a category (placeholder implementation)
        # @param category [Entities::Category] the category
        # @return [Integer] item count
        def calculate_item_count(category)
          # This would typically query the items/products table
          # For now, return a placeholder
          0
        end

        # Estimates popularity of a category (placeholder implementation)
        # @param category [Entities::Category] the category
        # @return [Float] popularity score
        def estimate_popularity(category)
          # This would typically use analytics data
          # For now, return a placeholder based on name length
          category.name.to_s.length / 50.0
        end

        # Calculates average depth of categories
        # @return [Float] average depth
        def calculate_average_depth
          # Placeholder implementation
          2.5
        end

        # Calculates maximum depth of categories
        # @return [Integer] maximum depth
        def calculate_max_depth
          # Placeholder implementation
          5
        end

        # Calculates number of categories with items
        # @return [Integer] count of categories with items
        def calculate_categories_with_items
          # Placeholder implementation
          @repository.count / 2
        end
      end
    end
  end
end