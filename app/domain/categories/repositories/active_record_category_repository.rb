# frozen_string_literal: true

module Categories
  module Repositories
    # ActiveRecord implementation of CategoryRepository
    class ActiveRecordCategoryRepository < CategoryRepository
      # @param model_class [Class] the ActiveRecord model class (default: ::Category)
      def initialize(model_class = ::Category)
        @model_class = model_class
      end

      # Finds a category by its unique identifier
      # @param id [String] the category identifier
      # @return [Entities::Category, nil] the category or nil if not found
      def find_by_id(id)
        record = @model_class.find_by(id: id)
        return nil unless record

        build_entity_from_record(record)
      end

      # Finds a category by its materialized path
      # @param path [ValueObjects::CategoryPath] the category path
      # @return [Entities::Category, nil] the category or nil if not found
      def find_by_path(path)
        record = @model_class.find_by(materialized_path: path.to_s)
        return nil unless record

        build_entity_from_record(record)
      end

      # Finds all root categories
      # @return [Array<Entities::Category>] array of root categories
      def find_roots
        records = @model_class.where(parent_id: nil).order(:materialized_path)
        records.map { |record| build_entity_from_record(record) }
      end

      # Finds all children of a category
      # @param parent_path [ValueObjects::CategoryPath] parent category path
      # @return [Array<Entities::Category>] array of child categories
      def find_children(parent_path)
        # Use LIKE query for materialized path matching
        path_pattern = "#{parent_path}%"
        records = @model_class.where('materialized_path LIKE ? AND materialized_path != ?',
                                   path_pattern, parent_path.to_s)
                             .where('LENGTH(materialized_path) = LENGTH(?) + LENGTH(?) + 1',
                                   parent_path.to_s, @model_class.maximum(:name).to_s)
                             .order(:materialized_path)

        records.map { |record| build_entity_from_record(record) }
      end

      # Finds all ancestors of a category
      # @param category_path [ValueObjects::CategoryPath] category path
      # @return [Array<Entities::Category>] array of ancestor categories
      def find_ancestors(category_path)
        return [] if category_path.root?

        # Parse the path and find all ancestors
        path_segments = category_path.segments
        ancestor_paths = []
        current_path = ValueObjects::CategoryPath.new

        path_segments.each do |segment|
          current_path = current_path.child_path(segment)
          ancestor_paths << current_path
        end

        # Remove the category itself from ancestors
        ancestor_paths = ancestor_paths[0..-2] if ancestor_paths.any?

        records = @model_class.where(materialized_path: ancestor_paths.map(&:to_s))
        records.map { |record| build_entity_from_record(record) }
      end

      # Finds all descendants of a category using optimized SQL
      # @param category_path [ValueObjects::CategoryPath] category path
      # @return [Array<Entities::Category>] array of descendant categories
      def find_descendants(category_path)
        # Use PostgreSQL's ltree or LIKE for efficient descendant queries
        path_pattern = "#{category_path}%"
        records = @model_class.where('materialized_path LIKE ? AND materialized_path != ?',
                                   path_pattern, category_path.to_s)
                             .order(:materialized_path)

        records.map { |record| build_entity_from_record(record) }
      end

      # Finds categories by name pattern
      # @param name_pattern [String] name pattern to search for
      # @return [Array<Entities::Category>] array of matching categories
      def find_by_name_pattern(name_pattern)
        # Use ILIKE for case-insensitive pattern matching
        pattern = "%#{sanitize_sql_like(name_pattern)}%"
        records = @model_class.where('name ILIKE ?', pattern).order(:materialized_path)
        records.map { |record| build_entity_from_record(record) }
      end

      # Finds categories by status
      # @param status [ValueObjects::CategoryStatus] category status
      # @return [Array<Entities::Category>] array of categories with given status
      def find_by_status(status)
        records = @model_class.where(active: status.active?).order(:materialized_path)
        records.map { |record| build_entity_from_record(record) }
      end

      # Checks if a category name is unique within its level
      # @param name [ValueObjects::CategoryName] category name
      # @param parent_path [ValueObjects::CategoryPath, nil] parent path or nil for root
      # @return [Boolean] true if name is unique
      def name_unique?(name, parent_path)
        query = @model_class.where(name: name.to_s)

        if parent_path&.root?
          query.where(parent_id: nil)
        elsif parent_path
          # Find parent by path and get its ID
          parent_record = @model_class.find_by(materialized_path: parent_path.to_s)
          return true unless parent_record
          query.where(parent_id: parent_record.id)
        else
          query.where(parent_id: nil)
        end

        query.none?
      end

      # Checks if moving a category would create a circular reference
      # @param category_id [String] category identifier
      # @param new_parent_path [ValueObjects::CategoryPath] new parent path
      # @return [Boolean] true if move would create circular reference
      def would_create_circular_reference?(category_id, new_parent_path)
        # Check if any descendant of the target path is the category being moved
        descendants = find_descendants(new_parent_path)
        descendants.any? { |descendant| descendant.id == category_id }
      end

      # Saves a category to the repository
      # @param category [Entities::Category] the category to save
      # @return [Entities::Category] the saved category
      def save(category)
        record = if category.id
                   @model_class.find_or_initialize_by(id: category.id)
                 else
                   @model_class.new
                 end

        # Map entity attributes to record
        record.name = category.name.to_s
        record.description = category.description
        record.materialized_path = category.path.to_s
        record.active = category.status.active?

        # Handle parent relationship
        if category.path.root?
          record.parent_id = nil
        else
          parent_path = category.path.parent_path
          parent_record = @model_class.find_by(materialized_path: parent_path.to_s)
          record.parent_id = parent_record&.id
        end

        if record.save
          # Return updated entity with record data
          build_entity_from_record(record)
        else
          # Handle validation errors
          raise ValidationError, record.errors.full_messages.join(', ')
        end
      end

      # Deletes a category from the repository
      # @param category [Entities::Category] the category to delete
      # @return [Boolean] true if deletion was successful
      def delete(category)
        record = @model_class.find_by(id: category.id)
        return false unless record

        record.destroy
      end

      # Counts total number of categories
      # @return [Integer] total count of categories
      def count
        @model_class.count
      end

      private

      # Builds a domain entity from an ActiveRecord record
      # @param record [Category] ActiveRecord record
      # @return [Entities::Category] domain entity
      def build_entity_from_record(record)
        path = ValueObjects::CategoryPath.new(record.materialized_path)
        name = ValueObjects::CategoryName.new(record.name)
        status = ValueObjects::CategoryStatus.new(record.active? ? :active : :inactive)

        Entities::Category.new(
          name: name,
          description: record.description,
          path: path,
          status: status,
          id: record.id
        )
      end

      # Sanitizes SQL LIKE patterns to prevent injection
      # @param pattern [String] pattern to sanitize
      # @return [String] sanitized pattern
      def sanitize_sql_like(pattern)
        pattern.gsub(/[_%\\]/) { |char| "\\#{char}" }
      end

      # Custom validation error class
      class ValidationError < StandardError; end
    end
  end
end