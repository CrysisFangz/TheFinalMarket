# CategoryService: Encapsulates business logic for category operations.
# This service adheres to the Single Responsibility Principle, handling creation,
# updating, and querying of categories with optimized performance and error handling.
# Designed for high scalability and modularity, allowing easy integration with
# asynchronous processing or microservices in the future.

class CategoryService
  include ActiveModel::Validations

  # Retrieves main categories with subcategories, optimized to avoid N+1 queries.
  # Uses eager loading and ordering for efficiency.
  def self.main_categories_with_subcategories
    Category.main_categories.includes(:subcategories).order(:position)
  end

  # Finds a category by ID with associated items, optimized for pagination and includes.
  def self.find_category_with_items(category_id, page: 1)
    category = Category.find(category_id)
    items = category.items.active
                    .includes(:user, :images_attachments)
                    .order(created_at: :desc)
                    .page(page)
    { category: category, items: items }
  end

  # Creates a new category, handling validation and potential hierarchy constraints.
  # Returns a ServiceResult for consistent error handling.
  def self.create_category(params, current_user)
    category = Category.new(params)
    category.user = current_user if current_user

    # Use custom validator for enhanced validation.
    validator = CategoryValidator.new
    validator.validate(category)

    if category.errors.empty? && category.save
      ServiceResult.success(CategoryPresenter.new(category).as_json, 'Category created successfully.')
    else
      ServiceResult.failure(category.errors.full_messages)
    end
  end

  # Updates an existing category, ensuring no self-referential or invalid hierarchy.
  def self.update_category(category, params)
    category.assign_attributes(params)

    # Use custom validator.
    validator = CategoryValidator.new
    validator.validate(category)

    if category.errors.empty? && category.save
      ServiceResult.success(CategoryPresenter.new(category).as_json, 'Category updated successfully.')
    else
      ServiceResult.failure(category.errors.full_messages)
    end
  end

  # Retrieves categories excluding the given category and its descendants for editing.
  def self.categories_for_editing(exclude_category)
    Category.where.not(id: [exclude_category.id] + exclude_category.descendants.pluck(:id))
  end

  # Validates category parameters with strict type checking and security.
  def self.validate_params(params)
    permitted = params.require(:category).permit(:name, :description, :parent_id, :active, :position)
    # Additional validation: Ensure position is numeric, active is boolean, etc.
    permitted[:position] = permitted[:position].to_i if permitted[:position]
    permitted[:active] = ActiveModel::Type::Boolean.new.cast(permitted[:active])
    permitted
  end
end

# ServiceResult: A simple result object for handling success/failure consistently.
# Enhances error handling and makes the code more testable and modular.
class ServiceResult
  attr_reader :success, :data, :message, :errors

  def self.success(data, message = nil)
    new(true, data, message)
  end

  def self.failure(errors)
    new(false, nil, nil, errors)
  end

  private

  def initialize(success, data, message, errors = nil)
    @success = success
    @data = data
    @message = message
    @errors = errors
  end
end