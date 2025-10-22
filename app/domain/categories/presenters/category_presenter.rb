# frozen_string_literal: true

module Categories
  module Presenters
    # Presenter for transforming category entities into various formats
    class CategoryPresenter
      # @param category [Entities::Category] category entity
      def initialize(category)
        @category = category
      end

      # Presents category as a hash for API responses
      # @param include_relations [Boolean] whether to include related data
      # @return [Hash] category data for API
      def to_api_hash(include_relations: false)
        hash = {
          id: @category.id,
          name: @category.name.to_s,
          description: @category.description,
          path: @category.path.to_s,
          depth: @category.depth,
          status: @category.status.to_s,
          active: @category.active?,
          root: @category.root?,
          leaf: @category.leaf?,
          created_at: @category.created_at,
          updated_at: @category.updated_at
        }

        if include_relations
          hash[:ancestors] = get_ancestors_data
          hash[:children_count] = get_children_count
          hash[:item_count] = get_item_count
        end

        hash
      end

      # Presents category as a tree node for hierarchical display
      # @param options [Hash] presentation options
      # @return [Hash] tree node data
      def to_tree_node(options = {})
        options = {
          include_item_count: true,
          max_depth: nil,
          current_depth: 0
        }.merge(options)

        node = {
          id: @category.id,
          name: @category.name.to_s,
          path: @category.path.to_s,
          depth: @category.depth,
          active: @category.active?,
          leaf: @category.leaf?,
          expanded: false,
          selected: false
        }

        if options[:include_item_count]
          node[:item_count] = get_item_count
        end

        # Add children if within depth limit and category can have children
        if options[:max_depth].nil? || options[:current_depth] < options[:max_depth]
          node[:children] = get_children_nodes(options)
          node[:has_children] = node[:children].any?
        else
          node[:has_children] = @category.can_have_children?
        end

        node
      end

      # Presents category for breadcrumb navigation
      # @return [Hash] breadcrumb data
      def to_breadcrumb
        {
          id: @category.id,
          name: @category.name.to_s,
          path: @category.path.to_s,
          url_path: generate_url_path
        }
      end

      # Presents category for search results
      # @param query [String] the search query used
      # @return [Hash] search result data
      def to_search_result(query)
        {
          id: @category.id,
          name: @category.name.to_s,
          description: @category.description,
          path: @category.path.to_s,
          full_path_display: generate_full_path_display,
          relevance_score: calculate_relevance_score(query),
          active: @category.active?,
          item_count: get_item_count
        }
      end

      # Presents category statistics for analytics
      # @return [Hash] statistical data
      def to_statistics
        {
          id: @category.id,
          name: @category.name.to_s,
          path: @category.path.to_s,
          depth: @category.depth,
          status: @category.status.to_s,
          age_days: calculate_age_in_days,
          item_count: get_item_count,
          children_count: get_children_count,
          has_children: @category.can_have_children?,
          popularity_score: calculate_popularity_score
        }
      end

      # Presents minimal category data for listings
      # @return [Hash] minimal category data
      def to_list_item
        {
          id: @category.id,
          name: @category.name.to_s,
          path: @category.path.to_s,
          active: @category.active?,
          item_count: get_item_count
        }
      end

      # Presents category for export operations
      # @param format [Symbol] export format (:csv, :json, :xml)
      # @return [Hash, Array, String] exported data
      def to_export(format)
        case format
        when :csv
          to_csv_row
        when :json
          to_api_hash(include_relations: true)
        when :xml
          to_xml_data
        else
          raise ArgumentError, "Unsupported export format: #{format}"
        end
      end

      private

      # Gets ancestors data for API responses
      # @return [Array<Hash>] ancestors data
      def get_ancestors_data
        # This would typically use a repository or service to get ancestors
        # For now, return empty array
        []
      end

      # Gets children count for category
      # @return [Integer] number of direct children
      def get_children_count
        # This would typically query the repository
        # For now, return 0
        0
      end

      # Gets item count for category
      # @return [Integer] number of items in category
      def get_item_count
        # This would typically query the items table
        # For now, return 0
        0
      end

      # Gets children nodes for tree display
      # @param options [Hash] presentation options
      # @return [Array<Hash>] children tree nodes
      def get_children_nodes(options)
        # This would typically use a repository or service to get children
        # For now, return empty array
        []
      end

      # Generates URL path for breadcrumb
      # @return [String] URL path
      def generate_url_path
        @category.path.segments.map(&:downcase).join('/')
      end

      # Generates full path display for search results
      # @return [String] human-readable path
      def generate_full_path_display
        @category.path.segments.join(' > ')
      end

      # Calculates relevance score for search results
      # @param query [String] search query
      # @return [Float] relevance score
      def calculate_relevance_score(query)
        return 1.0 unless query

        name_similarity = calculate_string_similarity(@category.name.to_s.downcase, query.downcase)
        path_similarity = calculate_string_similarity(@category.path.to_s.downcase, query.downcase)

        [name_similarity, path_similarity].max
      end

      # Calculates string similarity using Levenshtein distance
      # @param str1 [String] first string
      # @param str2 [String] second string
      # @return [Float] similarity score between 0 and 1
      def calculate_string_similarity(str1, str2)
        return 1.0 if str1 == str2

        # Simple similarity calculation based on substring matching
        shorter, longer = [str1, str2].sort_by(&:length)
        return 0.0 if shorter.empty?

        # Check if shorter is contained in longer
        if longer.include?(shorter)
          shorter.length.to_f / longer.length
        else
          0.0
        end
      end

      # Calculates age of category in days
      # @return [Integer] age in days
      def calculate_age_in_days
        return 0 unless @category.created_at

        ((Time.current - @category.created_at) / 1.day).to_i
      end

      # Calculates popularity score based on various factors
      # @return [Float] popularity score
      def calculate_popularity_score
        # This would typically use analytics data
        # For now, return a score based on name length and depth
        base_score = @category.name.to_s.length / 50.0
        depth_penalty = @category.depth * 0.1
        [base_score - depth_penalty, 0.0].max
      end

      # Converts category to CSV row
      # @return [Array] CSV row data
      def to_csv_row
        [
          @category.id,
          @category.name.to_s,
          @category.description,
          @category.path.to_s,
          @category.status.to_s,
          @category.depth,
          @category.created_at,
          @category.updated_at
        ]
      end

      # Converts category to XML data structure
      # @return [Hash] XML-ready data structure
      def to_xml_data
        {
          category: {
            id: @category.id,
            name: @category.name.to_s,
            description: @category.description,
            path: @category.path.to_s,
            status: @category.status.to_s,
            depth: @category.depth,
            active: @category.active?,
            created_at: @category.created_at,
            updated_at: @category.updated_at
          }
        }
      end
    end
  end
end