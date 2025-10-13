# frozen_string_literal: true

require 'test_helper'

class ProductTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @product = Product.new(
      name: "Test Product",
      description: "A great test product with detailed description",
      price: 99.99,
      user: @user
    )
  end

  # === Basic Validations ===

  test "should be valid with valid attributes" do
    assert @product.valid?
  end

  test "name should be present" do
    @product.name = "   "
    assert_not @product.valid?
  end

  test "description should be present" do
    @product.description = "   "
    assert_not @product.valid?
  end

  test "price should be present" do
    @product.price = nil
    assert_not @product.valid?
  end

  test "name should not be too long" do
    @product.name = "a" * 101
    assert_not @product.valid?
  end

  test "description should not be too long" do
    @product.description = "a" * 1001
    assert_not @product.valid?
  end

  test "price should be non-negative" do
    @product.price = -10.00
    assert_not @product.valid?
  end

  test "price should be numeric" do
    @product.price = "not_a_number"
    assert_not @product.valid?
  end

  # === Associations ===

  test "should belong to user" do
    assert_respond_to @product, :user
    assert_equal @user, @product.user
  end

  test "should have many categories through product_categories" do
    product = products(:one)
    assert_respond_to product, :categories
    assert_respond_to product, :product_categories
  end

  test "should have many tags through product_tags" do
    product = products(:one)
    assert_respond_to product, :tags
    assert_respond_to product, :product_tags
  end

  test "should have many product_images" do
    product = products(:one)
    assert_respond_to product, :product_images
  end

  test "should have many reviews" do
    product = products(:one)
    assert_respond_to product, :reviews
  end

  test "should have many variants" do
    product = products(:one)
    assert_respond_to product, :variants
  end

  # === Tag Management ===

  test "tag_list should return comma-separated tag names" do
    product = products(:one)
    product.tags.create(name: 'electronics')
    product.tags.create(name: 'gadgets')

    assert_equal 'electronics, gadgets', product.tag_list
  end

  test "tag_list= should create and assign tags" do
    @product.tag_list = "electronics, gadgets, test"
    @product.save

    assert_equal 3, @product.tags.count
    assert @product.tags.pluck(:name).include?('electronics')
    assert @product.tags.pluck(:name).include?('gadgets')
    assert @product.tags.pluck(:name).include?('test')
  end

  test "tag_list= should handle empty strings" do
    @product.tag_list = ""
    @product.save

    assert_equal 0, @product.tags.count
  end

  test "tag_list= should strip whitespace from tag names" do
    @product.tag_list = " electronics , gadgets , test "
    @product.save

    assert_equal 3, @product.tags.count
    assert @product.tags.pluck(:name).include?('electronics')
  end

  # === Variant Management ===

  test "should create default variant after creation" do
    @product.save
    assert_equal 1, @product.variants.count
    assert_equal @product.price, @product.variants.first.price
    assert_equal 'Default', @product.variants.first.name
  end

  test "default_variant should return first variant" do
    @product.save
    default = @product.default_variant

    assert_equal @product.variants.first, default
    assert_equal @product.price, default.price
  end

  test "default_variant should build new variant if none exist" do
    product = Product.new(name: "Test", description: "Test", price: 10.00, user: @user)
    # Don't save to avoid creating default variant

    variant = product.default_variant
    assert variant.new_record?
    assert_equal 10.00, variant.price
  end

  test "available_variants should return only active variants" do
    @product.save
    @product.variants.create(price: 89.99, stock_quantity: 10, active: false)
    @product.variants.create(price: 109.99, stock_quantity: 5, active: true)

    available = @product.available_variants
    assert_equal 2, available.count # Default + active variant
    assert available.all?(&:active?)
  end

  test "has_variants? should return true when multiple variants exist" do
    @product.save
    @product.variants.create(price: 89.99, stock_quantity: 10)

    assert @product.has_variants?
  end

  test "has_variants? should return false when only default variant exists" do
    @product.save

    assert_not @product.has_variants?
  end

  test "min_price should return minimum variant price" do
    @product.save
    @product.variants.create(price: 79.99, stock_quantity: 10)
    @product.variants.create(price: 119.99, stock_quantity: 5)

    assert_equal 79.99, @product.min_price
  end

  test "max_price should return maximum variant price" do
    @product.save
    @product.variants.create(price: 79.99, stock_quantity: 10)
    @product.variants.create(price: 119.99, stock_quantity: 5)

    assert_equal 119.99, @product.max_price
  end

  test "total_stock should return sum of all variant stock" do
    @product.save
    @product.variants.create(price: 79.99, stock_quantity: 10)
    @product.variants.create(price: 119.99, stock_quantity: 5)

    assert_equal 15, @product.total_stock
  end

  # === Elasticsearch Integration ===

  test "should include Elasticsearch modules" do
    assert @product.class.include?(Elasticsearch::Model)
    assert @product.class.include?(Elasticsearch::Model::Callbacks)
  end

  test "as_indexed_json should include required fields" do
    @product.save
    category = categories(:one)
    @product.categories << category
    @product.tags.create(name: 'test')

    indexed_json = @product.as_indexed_json

    assert_respond_to indexed_json, :[]
    assert_equal @product.name, indexed_json['name']
    assert_equal @product.description, indexed_json['description']
    assert_equal @product.price, indexed_json['price']
    assert indexed_json.key?('category')
    assert indexed_json.key?('tags')
    assert indexed_json.key?('average_rating')
    assert indexed_json.key?('total_reviews')
    assert indexed_json.key?('variants')
  end

  test "as_indexed_json should include variant details" do
    @product.save
    variant = @product.variants.first
    variant.update(sku: 'TEST-SKU-001')

    indexed_json = @product.as_indexed_json
    variants_data = indexed_json['variants']

    assert_equal 1, variants_data.length
    assert_equal variant.sku, variants_data.first['sku']
    assert_equal variant.price, variants_data.first['price']
    assert_equal variant.stock_quantity, variants_data.first['stock_quantity']
  end

  # === Search Functionality ===

  test "search_with_analytics should call AdvancedSearchService" do
    query = "test query"
    filters = { category: 'electronics' }
    page = 1
    per_page = 20

    mock_service = Minitest::Mock.new
    mock_service.expect(:search, { total: 0, suggestions: [] })

    AdvancedSearchService.stub(:new, mock_service) do
      Product.search_with_analytics(
        query: query,
        filters: filters,
        page: page,
        per_page: per_page
      )
    end

    mock_service.verify
  end

  test "search_with_analytics should track analytics for authenticated user" do
    user = users(:one)
    query = "test query"
    filters = { category: 'electronics' }

    mock_service = Minitest::Mock.new
    mock_service.expect(:search, { total: 5, suggestions: ['suggestion1'] })

    AdvancedSearchService.stub(:new, mock_service) do
      Product.search_with_analytics(
        query: query,
        filters: filters,
        user: user
      )
    end

    # Verify analytics event was created
    event = Ahoy::Event.last
    assert_equal 'product_search', event.name
    assert_equal user, event.user
    assert_equal query, event.properties['query']
    assert_equal filters, event.properties['filters']

    mock_service.verify
  end

  test "search_with_analytics should cache suggestions for successful searches" do
    query = "test query"

    mock_service = Minitest::Mock.new
    suggestions = ['suggestion1', 'suggestion2']
    mock_service.expect(:search, { total: 5, suggestions: suggestions })

    AdvancedSearchService.stub(:new, mock_service) do
      Product.search_with_analytics(query: query)
    end

    # Verify suggestions were cached
    cached = Rails.cache.read("search_suggestions:#{query.downcase}")
    assert_equal suggestions, cached

    mock_service.verify
  end

  # === Ransack Configuration ===

  test "ransackable_attributes should include required attributes" do
    attributes = Product.ransackable_attributes

    assert_includes attributes, 'name'
    assert_includes attributes, 'price'
    assert_includes attributes, 'brand'
    assert_includes attributes, 'created_at'
    assert_includes attributes, 'updated_at'
    assert_includes attributes, 'status'
    assert_includes attributes, 'availability'
  end

  test "ransackable_associations should include required associations" do
    associations = Product.ransackable_associations

    assert_includes associations, 'categories'
    assert_includes associations, 'tags'
    assert_includes associations, 'reviews'
    assert_includes associations, 'user'
  end

  # === Nested Attributes ===

  test "should accept nested attributes for product_images" do
    assert @product.respond_to?(:product_images_attributes=)
  end

  test "should accept nested attributes for option_types" do
    assert @product.respond_to?(:option_types_attributes=)
  end

  test "should accept nested attributes for variants" do
    assert @product.respond_to?(:variants_attributes=)
  end

  # === Dynamic Pricing Integration ===

  test "should have pricing_rules association" do
    product = products(:one)
    assert_respond_to product, :pricing_rules
  end

  test "should have price_changes association" do
    product = products(:one)
    assert_respond_to product, :price_changes
  end

  test "should have price_experiments association" do
    product = products(:one)
    assert_respond_to product, :price_experiments
  end

  # === Internationalization Support ===

  test "should have content_translations association" do
    product = products(:one)
    assert_respond_to product, :content_translations
  end

  test "should belong to origin_country" do
    product = products(:one)
    assert_respond_to product, :origin_country
  end

  # === Edge Cases and Error Handling ===

  test "should handle missing user gracefully" do
    product = Product.new(name: "Test", description: "Test", price: 10.00)
    # user is required, so this should be invalid
    assert_not product.valid?
  end

  test "should handle zero price" do
    @product.price = 0.0
    assert @product.valid?
  end

  test "should handle very large price" do
    @product.price = 999999.99
    assert @product.valid?
  end

  test "should handle special characters in name and description" do
    @product.name = "Test Product with Spëcial Châractérs & Symbols!"
    @product.description = "Description with émojis 🚀 and spëcial châractérs"
    assert @product.valid?
  end

  # === Performance and Memory ===

  test "should not create N+1 queries for basic operations" do
    product = products(:one)

    # Preload associations to avoid N+1 queries
    assert_sql_queries(1) do
      product.categories.to_a
      product.tags.to_a
      product.reviews.to_a
    end
  end
end
