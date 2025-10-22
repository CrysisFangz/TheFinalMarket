# frozen_string_literal: true

module Categories
  module Services
    # Domain service for complex category operations
    class CategoryDomainService
      # @param repository [Repositories::CategoryRepository] repository instance
      def initialize(repository)
        @repository = repository
      end

      # Moves a category to a new parent with validation
      # @param category_id [String] category to move
      # @param new_parent_path [ValueObjects::CategoryPath] new parent path
      # @return [Entities::Category] the moved category
      # @raise [ValidationError] if move is invalid
      def move_category(category_id, new_parent_path)
        category = @repository.find_by_id(category_id)
        raise ValidationError, "Category not found: #{category_id}" unless category

        validate_move_operation(category, new_parent_path)

        # Create new category with updated path
        moved_category = category.move_to(new_parent_path)

        # Save and update children paths if any
        saved_category = @repository.save(moved_category)
        update_children_paths(saved_category)

        saved_category
      end

      # Validates if a category can be safely deleted
      # @param category [Entities::Category] category to validate
      # @return [Hash] validation result with safety status and warnings
      def validate_deletion(category)
        result = {
          can_delete: true,
          warnings: [],
          errors: []
        }

        # Check if category has children
        children = @repository.find_children(category.path)
        if children.any?
          result[:can_delete] = false
          result[:errors] << "Cannot delete category with children. Move or delete children first."
        end

        # Check if category has items (placeholder - would need items repository)
        item_count = calculate_item_count(category)
        if item_count > 0
          result[:warnings] << "Category contains #{item_count} items that will be affected by deletion."
        end

        # Check if category is root level
        if category.root?
          root_count = @repository.find_roots.count
          if root_count <= 1
            result[:warnings] << "Deleting the last root category may impact system functionality."
          end
        end

        result
      end

      # Merges two categories by moving all children and items
      # @param source_category [Entities::Category] category to merge from
      # @param target_category [Entities::Category] category to merge into
      # @return [Entities::Category] the updated target category
      # @raise [ValidationError] if merge is invalid
      def merge_categories(source_category, target_category)
        raise ValidationError, "Cannot merge category with itself" if source_category == target_category

        # Validate merge operation
        unless source_category.active? && target_category.active?
          raise ValidationError, "Both categories must be active to merge"
        end

        unless source_category.path.depth == target_category.path.depth
          raise ValidationError, "Cannot merge categories at different depths"
        end

        # Move children from source to target
        children = @repository.find_children(source_category.path)
        children.each do |child|
          new_path = target_category.path.child_path(child.name.to_s)
          moved_child = child.move_to(new_path)
          @repository.save(moved_child)
        end

        # Delete source category
        @repository.delete(source_category)

        target_category
      end

      # Rebuilds materialized paths for all categories (for maintenance)
      # @return [Integer] number of categories updated
      def rebuild_paths
        updated_count = 0
        categories = get_all_categories_for_rebuild

        categories.each do |category|
          correct_path = calculate_correct_path(category)
          next if category.path == correct_path

          updated_category = category.move_to(correct_path.parent_path)
          @repository.save(updated_category)
          updated_count += 1
        end

        updated_count
      end

      # Validates category tree integrity
      # @return [Hash] integrity report
      def validate_tree_integrity
        report = {
          valid: true,
          errors: [],
          warnings: [],
          statistics: {}
        }

        categories = get_all_categories_for_rebuild
        report[:statistics][:total_categories] = categories.count

        # Check for path consistency
        categories.each do |category|
          correct_path = calculate_correct_path(category)
          unless category.path == correct_path
            report[:errors] << "Invalid path for category #{category.id}: expected #{correct_path}, got #{category.path}"
            report[:valid] = false
          end
        end

        # Check for circular references
        categories.each do |category|
          if would_create_circular_reference(category)
            report[:errors] << "Circular reference detected for category #{category.id}"
            report[:valid] = false
          end
        end

        # Check for duplicate names at same level
        name_conflicts = find_name_conflicts(categories)
        if name_conflicts.any?
          report[:warnings] << "Duplicate category names found: #{name_conflicts.join(', ')}"
        end

        report
      end

      private

      # Validates a move operation
      # @param category [Entities::Category] category to move
      # @param new_parent_path [ValueObjects::CategoryPath] new parent path
      # @raise [ValidationError] if move is invalid
      def validate_move_operation(category, new_parent_path)
        # Check for circular reference
        if @repository.would_create_circular_reference?(category.id, new_parent_path)
          raise ValidationError, "Move would create a circular reference"
        end

        # Check depth constraints
        new_depth = new_parent_path.depth + 1
        unless new_depth <= Entities::Category::MAX_DEPTH
          raise ValidationError, "Move would exceed maximum depth of #{Entities::Category::MAX_DEPTH}"
        end

        # Check if target exists and is valid
        unless new_parent_path.root?
          target_category = @repository.find_by_path(new_parent_path)
          unless target_category
            raise ValidationError, "Target parent category does not exist"
          end
          unless target_category.active?
            raise ValidationError, "Target parent category is not active"
          end
        end

        # Check if category is being moved to itself
        if category.path == new_parent_path
          raise ValidationError, "Cannot move category to its current location"
        end
      end

      # Updates paths of all children after a parent move
      # @param category [Entities::Category] the moved category
      def update_children_paths(category)
        children = @repository.find_children(category.path)
        children.each do |child|
          new_path = category.path.child_path(child.name.to_s)
          updated_child = child.move_to(new_path)
          @repository.save(updated_child)

          # Recursively update deeper children
          update_children_paths(updated_child)
        end
      end

      # Calculates correct path for a category based on its parent relationship
      # @param category [Entities::Category] category to calculate path for
      # @return [ValueObjects::CategoryPath] correct path
      def calculate_correct_path(category)
        if category.root?
          ValueObjects::CategoryPath.new("/#{category.name}/")
        else
          # This would need to traverse up to find correct parent path
          # For now, return current path
          category.path
        end
      end

      # Gets all categories for rebuild operations
      # @return [Array<Entities::Category>] all categories
      def get_all_categories_for_rebuild
        @repository.find_roots.flat_map do |root|
          [root] + get_all_descendants(root)
        end
      end

      # Gets all descendants of a category recursively
      # @param category [Entities::Category] parent category
      # @return [Array<Entities::Category>] all descendants
      def get_all_descendants(category)
        children = @repository.find_children(category.path)
        children.flat_map do |child|
          [child] + get_all_descendants(child)
        end
      end

      # Checks if a category would create a circular reference
      # @param category [Entities::Category] category to check
      # @return [Boolean] true if circular reference would be created
      def would_create_circular_reference(category)
        # This is a simplified check - in practice, would need more sophisticated logic
        false
      end

      # Finds categories with duplicate names at the same level
      # @param categories [Array<Entities::Category>] categories to check
      # @return [Array<String>] list of conflicting category names
      def find_name_conflicts(categories)
        # Group by parent path and name, find duplicates
        conflicts = []
        categories_by_parent = categories.group_by(&:path)

        categories_by_parent.each do |parent_path, sibling_categories|
          names = sibling_categories.map(&:name).map(&:to_s)
          duplicates = names.select { |name| names.count(name) > 1 }.uniq
          conflicts.concat(duplicates) if duplicates.any?
        end

        conflicts
      end

      # Calculates item count for a category (placeholder)
      # @param category [Entities::Category] category to count items for
      # @return [Integer] item count
      def calculate_item_count(category)
        # This would typically query the items/products table
        0
      end

      # Custom validation error class
      class ValidationError < StandardError; end
    end
  end
end