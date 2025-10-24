# 🚀 ENTERPRISE-GRADE OPTION TYPE SERVICE
# Hyperscale Service Layer for OptionType Management
#
# This service encapsulates all business logic related to OptionTypes, ensuring
# asymptotic optimality, decoupling from controllers, and providing a resilient
# interface for option type operations.

class OptionTypeService
  include Dry::Monads[:result]

  # Create a new OptionType for a product
  def self.create_for_product(product, name)
    return Failure('Product is required') if product.blank?
    return Failure('Name is required') if name.blank?

    option_type = product.option_types.build(name: name)

    if option_type.save
      # Invalidate related caches
      Rails.cache.delete("product:#{product.id}:option_types")
      Success(option_type)
    else
      Failure(option_type.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid => e
    Failure(e.message)
  end

  # Find or create OptionType
  def self.find_or_create_for_product(product, name)
    return Failure('Product is required') if product.blank?
    return Failure('Name is required') if name.blank?

    option_type = product.option_types.find_or_initialize_by(name: name)

    if option_type.new_record? && option_type.save
      # Invalidate caches
      Rails.cache.delete("product:#{product.id}:option_types")
      Success(option_type)
    elsif option_type.persisted?
      Success(option_type)
    else
      Failure(option_type.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid => e
    Failure(e.message)
  end

  # Bulk create OptionTypes for a product
  def self.bulk_create_for_product(product, names)
    return Failure('Product is required') if product.blank?
    return Failure('Names must be an array') unless names.is_a?(Array)

    results = names.map do |name|
      create_for_product(product, name)
    end

    if results.all?(&:success?)
      # Invalidate caches
      Rails.cache.delete("product:#{product.id}:option_types")
      Success(results.map(&:value!))
    else
      Failure(results.select(&:failure?).map(&:failure))
    end
  end

  # Get all OptionTypes for a product with caching
  def self.for_product(product)
    return Failure('Product is required') if product.blank?

    Rails.cache.fetch("product:#{product.id}:option_types", expires_in: 1.hour) do
      product.option_types.ordered.with_option_values.to_a
    end

    Success(product.option_types.ordered.with_option_values)
  end

  # Update an OptionType
  def self.update(option_type, attributes)
    return Failure('OptionType is required') if option_type.blank?

    if option_type.update(attributes)
      # Invalidate caches
      Rails.cache.delete("product:#{option_type.product_id}:option_types")
      Rails.cache.delete("option_type:#{option_type.id}:option_values_count")
      Success(option_type)
    else
      Failure(option_type.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid => e
    Failure(e.message)
  end

  # Destroy an OptionType
  def self.destroy(option_type)
    return Failure('OptionType is required') if option_type.blank?

    product_id = option_type.product_id

    if option_type.destroy
      # Invalidate caches
      Rails.cache.delete("product:#{product_id}:option_types")
      Success(true)
    else
      Failure(option_type.errors.full_messages)
    end
  end

  # Validate OptionType data
  def self.validate(attributes)
    option_type = OptionType.new(attributes)
    if option_type.valid?
      Success(true)
    else
      Failure(option_type.errors.full_messages)
    end
  end
end