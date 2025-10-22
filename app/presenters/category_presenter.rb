# CategoryPresenter: Handles the presentation logic for Category objects, decoupling
# data formatting from the model and view. Ensures consistent, secure, and optimized
# output for API responses or views. Designed for high scalability and easy customization.

class CategoryPresenter
  attr_reader :category

  def initialize(category)
    @category = category
  end

  # Presents the category in a structured format for views or APIs.
  def as_json(options = {})
    {
      id: category.id,
      name: category.name,
      description: category.description,
      parent_id: category.parent_id,
      active: category.active,
      position: category.position,
      created_at: category.created_at.iso8601,
      updated_at: category.updated_at.iso8601,
      subcategories: subcategories_json,
      full_path: full_path,
      depth: depth,
      metadata: metadata
    }.merge(options)
  end

  # Formats for index view: Simplified structure.
  def for_index
    {
      id: category.id,
      name: category.name,
      active: category.active,
      position: category.position,
      subcategories_count: category.subcategories.count
    }
  end

  # Formats for show view: Detailed with items summary.
  def for_show
    as_json.merge(
      items_count: category.items.active.count,
      recent_items: recent_items_json
    )
  end

  # Formats for edit/new forms: Includes validation hints.
  def for_form
    as_json.merge(
      validation_rules: validation_rules,
      available_parents: available_parents_json
    )
  end

  private

  # Subcategories in JSON format.
  def subcategories_json
    category.subcategories.map { |sub| CategoryPresenter.new(sub).for_index }
  end

  # Full hierarchical path as a string.
  def full_path
    path = []
    current = category
    while current
      path.unshift(current.name)
      current = current.parent
    end
    path.join(' > ')
  end

  # Depth in the hierarchy.
  def depth
    category.ancestors.count
  end

  # Additional metadata for advanced features.
  def metadata
    {
      is_main: category.parent_id.nil?,
      has_subcategories: category.subcategories.any?,
      total_items: category.items.count
    }
  end

  # Recent items for show view.
  def recent_items_json
    category.items.active.order(created_at: :desc).limit(5).map do |item|
      {
        id: item.id,
        title: item.title,
        price: item.price,
        created_at: item.created_at.iso8601
      }
    end
  end

  # Validation rules for forms.
  def validation_rules
    {
      name: { required: true, max_length: 100 },
      description: { max_length: 500 },
      position: { type: :integer, min: 0 },
      active: { type: :boolean }
    }
  end

  # Available parents for selection.
  def available_parents_json
    Category.where.not(id: [category.id] + category.descendants.pluck(:id)).map do |cat|
      { id: cat.id, name: cat.name, full_path: CategoryPresenter.new(cat).full_path }
    end
  end
end