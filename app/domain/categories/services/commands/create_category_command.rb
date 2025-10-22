# frozen_string_literal: true

module Categories
  module Services
    module Commands
      # Command service for creating new categories
      class CreateCategoryCommand
        # @param repository [Repositories::CategoryRepository] repository instance
        # @param event_publisher [EventPublisher] event publisher (optional)
        def initialize(repository, event_publisher = nil)
          @repository = repository
          @event_publisher = event_publisher
        end

        # Creates a new category
        # @param name [ValueObjects::CategoryName] category name
        # @param description [String] category description (optional)
        # @param parent_path [ValueObjects::CategoryPath] parent path (optional)
        # @return [Entities::Category] the created category
        # @raise [ValidationError] if creation fails
        def execute(name:, description: nil, parent_path: nil)
          validate_inputs(name, parent_path)

          # Determine the path for the new category
          category_path = if parent_path&.root?
                            ValueObjects::CategoryPath.new("/#{name}/")
                          elsif parent_path
                            parent_path.child_path(name.to_s)
                          else
                            ValueObjects::CategoryPath.new("/#{name}/")
                          end

          # Check for uniqueness
          unless @repository.name_unique?(name, parent_path)
            raise ValidationError, "Category name '#{name}' already exists in the specified location"
          end

          # Create the category entity
          status = parent_path ? ValueObjects::CategoryStatus.new(:active) : ValueObjects::CategoryStatus.new(:pending)
          category = Entities::Category.new(
            name: name,
            description: description,
            path: category_path,
            status: status
          )

          # Save to repository
          saved_category = @repository.save(category)

          # Publish domain event
          publish_event(:category_created, saved_category)

          saved_category
        rescue StandardError => e
          publish_event(:category_creation_failed, category, error: e.message)
          raise ValidationError, "Failed to create category: #{e.message}"
        end

        private

        # Validates command inputs
        # @param name [ValueObjects::CategoryName] category name
        # @param parent_path [ValueObjects::CategoryPath] parent path
        # @raise [ValidationError] if validation fails
        def validate_inputs(name, parent_path)
          raise ValidationError, 'Category name is required' unless name
          raise ValidationError, 'Parent path cannot be deeper than maximum depth' if parent_path&.depth&.>=(Entities::Category::MAX_DEPTH)

          if parent_path && !parent_path.root?
            parent_category = @repository.find_by_path(parent_path)
            raise ValidationError, 'Parent category does not exist' unless parent_category
            raise ValidationError, 'Parent category is not active' unless parent_category.active?
          end
        end

        # Publishes a domain event
        # @param event_type [Symbol] type of event
        # @param category [Entities::Category] the category involved
        # @param metadata [Hash] additional event metadata
        def publish_event(event_type, category, metadata = {})
          return unless @event_publisher

          event_data = {
            event_type: event_type,
            category_id: category.id,
            category_name: category.name.to_s,
            category_path: category.path.to_s,
            timestamp: Time.current,
            **metadata
          }

          @event_publisher.publish("category.#{event_type}", event_data)
        end

        # Custom validation error class
        class ValidationError < StandardError; end
      end
    end
  end
end