# app/services/comparison_service.rb
#
# Service class for handling product comparison operations.
# Encapsulates business logic for adding, removing, clearing, and fetching comparison data.
# Ensures modularity, error handling, and performance optimizations.
#
# Key Features:
# - Validates operations to prevent invalid states.
# - Uses efficient database queries with eager loading.
# - Integrates with caching for repeated fetches.
# - Provides structured results for easy error handling in controllers.
#
class ComparisonService
  include ServiceResultHelper

  def initialize(user, compare_list)
    @user = user
    @compare_list = compare_list
    @max_items = 10  # Configurable limit
  end

  # Fetches comparison data with caching and optimization.
  def fetch_comparison_data
    Rails.cache.fetch("comparison_data_#{@compare_list.id}", expires_in: 5.minutes) do
      products = @compare_list.products.includes(:category, :reviews)  # Eager load to avoid N+1
      comparison_data = ProductComparisonService.new(products).compare_attributes
      success(comparison_data)
    end
  rescue => e
    Rails.logger.error("Error fetching comparison data for user: #{@user.id} - #{e.message}")
    failure(['Unable to load comparison data.'])
  end

  # Adds an item to the comparison list with validation.
  def add_item(product)
    return failure(['Comparison list is full.']) if @compare_list.compare_items.count >= @max_items
    return failure(['Product already in comparison.']) if @compare_list.compare_items.exists?(product: product)

    compare_item = @compare_list.compare_items.build(product: product)
    if compare_item.save
      # Invalidate cache
      Rails.cache.delete("comparison_data_#{@compare_list.id}")
      success(compare_item)
    else
      failure(compare_item.errors.full_messages)
    end
  rescue => e
    Rails.logger.error("Error adding item for user: #{@user.id} - #{e.message}")
    failure(['Failed to add product to comparison.'])
  end

  # Removes an item from the comparison list.
  def remove_item(product)
    compare_item = @compare_list.compare_items.find_by(product: product)
    if compare_item&.destroy
      Rails.cache.delete("comparison_data_#{@compare_list.id}")
      success(compare_item)
    else
      failure(['Product not found in comparison.'])
    end
  rescue => e
    Rails.logger.error("Error removing item for user: #{@user.id} - #{e.message}")
    failure(['Failed to remove product from comparison.'])
  end

  # Clears the entire comparison list efficiently.
  def clear_list
    if @compare_list.compare_items.destroy_all
      Rails.cache.delete("comparison_data_#{@compare_list.id}")
      success(true)
    else
      failure(['Failed to clear comparison list.'])
    end
  rescue => e
    Rails.logger.error("Error clearing list for user: #{@user.id} - #{e.message}")
    failure(['Failed to clear comparison list.'])
  end
end