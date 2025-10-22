# CategoryValidator: Custom validator for Category model to enforce business rules
# beyond basic ActiveRecord validations. Ensures data integrity, security, and
# compliance with enterprise standards. Designed for high modularity and extensibility.

class CategoryValidator < ActiveModel::Validator
  # Validates the category record with sophisticated rules.
  def validate(record)
    validate_name(record)
    validate_description(record)
    validate_parent_id(record)
    validate_position(record)
    validate_active(record)
    validate_hierarchy_integrity(record)
  end

  private

  # Validates the name field: Must be present, unique, and within length limits.
  def validate_name(record)
    if record.name.blank?
      record.errors.add(:name, 'cannot be blank')
    elsif record.name.length > 100
      record.errors.add(:name, 'must be less than 100 characters')
    elsif Category.where.not(id: record.id).exists?(name: record.name)
      record.errors.add(:name, 'must be unique')
    end
  end

  # Validates the description: Optional, but if present, must be within limits.
  def validate_description(record)
    if record.description && record.description.length > 500
      record.errors.add(:description, 'must be less than 500 characters')
    end
  end

  # Validates parent_id: Must reference a valid category, prevent self-referential loops.
  def validate_parent_id(record)
    if record.parent_id.present?
      parent = Category.find_by(id: record.parent_id)
      if parent.nil?
        record.errors.add(:parent_id, 'must reference a valid category')
      elsif parent.id == record.id
        record.errors.add(:parent_id, 'cannot be self-referential')
      elsif would_create_cycle?(record, parent)
        record.errors.add(:parent_id, 'would create a circular hierarchy')
      end
    end
  end

  # Validates position: Must be a non-negative integer.
  def validate_position(record)
    if record.position.nil? || record.position < 0
      record.errors.add(:position, 'must be a non-negative integer')
    end
  end

  # Validates active: Must be a boolean.
  def validate_active(record)
    unless [true, false].include?(record.active)
      record.errors.add(:active, 'must be true or false')
    end
  end

  # Ensures no circular hierarchies in category tree.
  def validate_hierarchy_integrity(record)
    # Additional checks for tree integrity, e.g., depth limits.
    if record.parent_id && depth_of(record) > 5
      record.errors.add(:parent_id, 'hierarchy depth exceeds maximum of 5 levels')
    end
  end

  # Helper to check for cycles in hierarchy.
  def would_create_cycle?(record, parent)
    ancestors = parent.ancestors.pluck(:id)
    ancestors.include?(record.id) || ancestors.include?(record.parent_id)
  end

  # Calculates depth of the category in the hierarchy.
  def depth_of(record)
    depth = 0
    current = record.parent
    while current
      depth += 1
      current = current.parent
    end
    depth
  end
end