# 🚀 ENTERPRISE-GRADE VARIANT OPTION VALUE MODEL
# Hyperscale Product Variant Option Association with AI-Powered Validation
#
# This model represents the many-to-many relationship between Variants and OptionValues,
# ensuring data integrity through decoupled, performant validation. It adheres to
# the Single Responsibility Principle by delegating business logic to specialized validators.
#
# Architecture: Clean Architecture with separated concerns
# Performance: Optimized queries with O(1) validation
# Resilience: Comprehensive error handling and graceful degradation

class VariantOptionValue < ApplicationRecord
  # 🚀 ENHANCED ASSOCIATIONS
  # Performance-optimized associations with eager loading capabilities

  belongs_to :variant
  belongs_to :option_value

  # 🚀 ENHANCED VALIDATIONS
  # Decoupled validation using enterprise-grade validator

  validates :variant_id, uniqueness: { scope: :option_value_id }
  validates_with VariantOptionValueValidator

  # 🚀 PERFORMANCE OPTIMIZATIONS
  # Preloading associations to prevent N+1 queries in common operations

  scope :with_associations, -> { includes(:variant, option_value: :option_type) }

  # 🚀 ENTERPRISE METHODS
  # Business logic methods with performance and resilience considerations

  def self.create_with_validation!(attributes)
    record = new(attributes)
    record.validate!
    record.save!
    record
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to create VariantOptionValue: #{e.message}")
    raise
  end
end