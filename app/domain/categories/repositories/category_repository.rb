# frozen_string_literal: true

module Categories
  module Repositories
    # Abstract repository interface for Category domain entities
    class CategoryRepository
      # Finds a category by its unique identifier
      # @param id [String] the category identifier
      # @return [Entities::Category, nil] the category or nil if not found
      def find_by_id(id)
        raise NotImplementedError, 'Subclasses must implement #find_by_id'
      end

      # Finds a category by its materialized path
      # @param path [ValueObjects::CategoryPath] the category path
      # @return [Entities::Category, nil] the category or nil if not found
      def find_by_path(path)
        raise NotImplementedError, 'Subclasses must implement #find_by_path'
      end

      # Finds all root categories
      # @return [Array<Entities::Category>] array of root categories
      def find_roots
        raise NotImplementedError, 'Subclasses must implement #find_roots'
      end

      # Finds all children of a category
      # @param parent_path [ValueObjects::CategoryPath] parent category path
      # @return [Array<Entities::Category>] array of child categories
      def find_children(parent_path)
        raise NotImplementedError, 'Subclasses must implement #find_children'
      end

      # Finds all ancestors of a category
      # @param category_path [ValueObjects::CategoryPath] category path
      # @return [Array<Entities::Category>] array of ancestor categories
      def find_ancestors(category_path)
        raise NotImplementedError, 'Subclasses must implement #find_ancestors'
      end

      # Finds all descendants of a category
      # @param category_path [ValueObjects::CategoryPath] category path
      # @return [Array<Entities::Category>] array of descendant categories
      def find_descendants(category_path)
        raise NotImplementedError, 'Subclasses must implement #find_descendants'
      end

      # Finds categories by name pattern
      # @param name_pattern [String] name pattern to search for
      # @return [Array<Entities::Category>] array of matching categories
      def find_by_name_pattern(name_pattern)
        raise NotImplementedError, 'Subclasses must implement #find_by_name_pattern'
      end

      # Finds categories by status
      # @param status [ValueObjects::CategoryStatus] category status
      # @return [Array<Entities::Category>] array of categories with given status
      def find_by_status(status)
        raise NotImplementedError, 'Subclasses must implement #find_by_status'
      end

      # Checks if a category name is unique within its level
      # @param name [ValueObjects::CategoryName] category name
      # @param parent_path [ValueObjects::CategoryPath, nil] parent path or nil for root
      # @return [Boolean] true if name is unique
      def name_unique?(name, parent_path)
        raise NotImplementedError, 'Subclasses must implement #name_unique?'
      end

      # Checks if moving a category would create a circular reference
      # @param category_id [String] category identifier
      # @param new_parent_path [ValueObjects::CategoryPath] new parent path
      # @return [Boolean] true if move would create circular reference
      def would_create_circular_reference?(category_id, new_parent_path)
        raise NotImplementedError, 'Subclasses must implement #would_create_circular_reference?'
      end

      # Saves a category to the repository
      # @param category [Entities::Category] the category to save
      # @return [Entities::Category] the saved category
      def save(category)
        raise NotImplementedError, 'Subclasses must implement #save'
      end

      # Deletes a category from the repository
      # @param category [Entities::Category] the category to delete
      # @return [Boolean] true if deletion was successful
      def delete(category)
        raise NotImplementedError, 'Subclasses must implement #delete'
      end

      # Counts total number of categories
      # @return [Integer] total count of categories
      def count
        raise NotImplementedError, 'Subclasses must implement #count'
      end

      # Checks if repository is empty
      # @return [Boolean] true if repository contains no categories
      def empty?
        count.zero?
      end
    end
  end
end