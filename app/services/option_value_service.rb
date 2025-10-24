# 🚀 ENTERPRISE-GRADE OPTION VALUE SERVICE
# Hyperscale Service Layer for OptionValue Management
#
# This service encapsulates all business logic related to OptionValues, ensuring
# asymptotic optimality, decoupling from controllers, and providing a resilient
# interface for option value operations.

class OptionValueService
  include Dry::Monads[:result]

  # Create a new OptionValue for an option_type
  def self.create_for_option_type(option_type, name)
    return Failure('OptionType is required') if option_type.blank?
    return Failure('Name is required') if name.blank?

    option_value = option_type.option_values.build(name: name)

    if option_value.save
      # Invalidate related caches
      Rails.cache.delete("option_type:#{option_type.id}:option_values")
      Success(option_value)
    else
      Failure(option_value.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid => e
    Failure(e.message)
  end

  # Find or create OptionValue
  def self.find_or_create_for_option_type(option_type, name)
    return Failure('OptionType is required') if option_type.blank?
    return Failure('Name is required') if name.blank?

    option_value = option_type.option_values.find_or_initialize_by(name: name)

    if option_value.new_record? && option_value.save
      # Invalidate caches
      Rails.cache.delete("option_type:#{option_type.id}:option_values")
      Success(option_value)
    elsif option_value.persisted?
      Success(option_value)
    else
      Failure(option_value.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid => e
    Failure(e.message)
  end

  # Bulk create OptionValues for an option_type
  def self.bulk_create_for_option_type(option_type, names)
    return Failure('OptionType is required') if option_type.blank?
    return Failure('Names must be an array') unless names.is_a?(Array)

    results = names.map do |name|
      create_for_option_type(option_type, name)
    end

    if results.all?(&:success?)
      # Invalidate caches
      Rails.cache.delete("option_type:#{option_type.id}:option_values")
      Success(results.map(&:value!))
    else
      Failure(results.select(&:failure?).map(&:failure))
    end
  end

  # Get all OptionValues for an option_type with caching
  def self.for_option_type(option_type)
    return Failure('OptionType is required') if option_type.blank?

    Rails.cache.fetch("option_type:#{option_type.id}:option_values", expires_in: 1.hour) do
      option_type.option_values.ordered.to_a
    end

    Success(option_type.option_values.ordered)
  end

  # Update an OptionValue
  def self.update(option_value, attributes)
    return Failure('OptionValue is required') if option_value.blank?

    if option_value.update(attributes)
      # Invalidate caches
      Rails.cache.delete("option_type:#{option_value.option_type_id}:option_values")
      Rails.cache.delete("option_value:#{option_value.id}:variants_count")
      Success(option_value)
    else
      Failure(option_value.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid => e
    Failure(e.message)
  end

  # Destroy an OptionValue
  def self.destroy(option_value)
    return Failure('OptionValue is required') if option_value.blank?

    option_type_id = option_value.option_type_id

    if option_value.destroy
      # Invalidate caches
      Rails.cache.delete("option_type:#{option_type_id}:option_values")
      Success(true)
    else
      Failure(option_value.errors.full_messages)
    end
  end

  # Validate OptionValue data
  def self.validate(attributes)
    option_value = OptionValue.new(attributes)
    if option_value.valid?
      Success(true)
    else
      Failure(option_value.errors.full_messages)
    end
  end
end