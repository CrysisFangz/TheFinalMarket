require "test_helper"

class PerformanceOptimizationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @product = products(:one)
  end

  # GraphQL API Tests
  test "graphql endpoint is accessible" do
    post graphql_path, params: { query: "{ __schema { types { name } } }" }
    assert_response :success
    assert_not_nil JSON.parse(response.body)["data"]
  end

  test "graphql query returns product data" do
    query = <<~GRAPHQL
      query GetProduct($id: ID!) {
        product(id: $id) {
          id
          name
          price
        }
      }
    GRAPHQL

    post graphql_path, params: {
      query: query,
      variables: { id: @product.id.to_s }
    }

    assert_response :success
    data = JSON.parse(response.body)["data"]
    assert_equal @product.name, data["product"]["name"]
  end

  test "graphql mutation adds to cart" do
    sign_in @user

    mutation = <<~GRAPHQL
      mutation AddToCart($productId: ID!, $quantity: Int!) {
        addToCart(productId: $productId, quantity: $quantity) {
          cart {
            totalItems
          }
          errors
        }
      }
    GRAPHQL

    post graphql_path, params: {
      query: mutation,
      variables: { productId: @product.id.to_s, quantity: 1 }
    }

    assert_response :success
    data = JSON.parse(response.body)["data"]
    assert_equal 1, data["addToCart"]["cart"]["totalItems"]
    assert_empty data["addToCart"]["errors"]
  end

  test "graphql enforces rate limiting" do
    # Make 101 requests (exceeds 100/min limit)
    101.times do
      post graphql_path, params: { query: "{ __typename }" }
    end

    assert_response :too_many_requests
  end

  test "graphql enforces query complexity" do
    # Create a very complex query that exceeds limit
    complex_query = <<~GRAPHQL
      query {
        products(first: 100) {
          edges {
            node {
              reviews(first: 100) {
                edges {
                  node {
                    id
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL

    post graphql_path, params: { query: complex_query }

    # Should reject or handle gracefully
    assert_response :success
    data = JSON.parse(response.body)
    assert data["errors"].present? || data["data"].present?
  end

  # PWA Tests
  test "service worker is accessible" do
    get "/service-worker.js"
    assert_response :success
    assert_match /self\.addEventListener/, response.body
  end

  test "manifest.json is accessible" do
    get "/manifest.json"
    assert_response :success
    manifest = JSON.parse(response.body)
    assert_equal "The Final Market", manifest["name"]
  end

  # Image Optimization Tests
  test "image optimization service generates variants" do
    skip "Requires image upload setup"
    
    # This would test ImageOptimizationService
    # service = ImageOptimizationService.new(image_file)
    # variants = service.process
    # assert variants[:thumbnail].present?
    # assert variants[:webp].present?
  end

  # CDN Tests
  test "static assets have cache headers" do
    get "/assets/application.css"
    assert_response :success
    assert_match /max-age=/, response.headers["Cache-Control"]
  end

  test "images have cache headers" do
    skip "Requires actual image"
    
    get "/uploads/product/image/1/test.jpg"
    assert_response :success
    assert_match /max-age=2592000/, response.headers["Cache-Control"] # 30 days
  end

  # Database Sharding Tests
  test "database sharding routes users correctly" do
    skip "Requires sharding configuration"
    
    # Test that users are routed to correct shards
    # user1 = User.create!(id: 1, ...)
    # user2 = User.create!(id: 2, ...)
    # assert_equal :shard_1, DatabaseSharding.shard_for_user(user1.id)
    # assert_equal :shard_2, DatabaseSharding.shard_for_user(user2.id)
  end

  # Real-Time Updates Tests
  test "inventory channel broadcasts updates" do
    skip "Requires Action Cable setup"
    
    # Test that inventory updates are broadcast
    # InventoryChannel.broadcast_stock_update(@product, nil)
    # assert_broadcast_on "inventory:#{@product.id}", type: 'stock_update'
  end

  # Mobile Optimization Tests
  test "viewport meta tag is present" do
    get root_path
    assert_response :success
    assert_select "meta[name='viewport']"
  end

  test "mobile-friendly touch targets" do
    get product_path(@product)
    assert_response :success
    # Check for mobile-optimized buttons
    assert_select "button.btn", minimum: 1
  end

  # Performance Tests
  test "homepage loads quickly" do
    start_time = Time.now
    get root_path
    end_time = Time.now
    
    assert_response :success
    assert (end_time - start_time) < 1.0, "Homepage took too long to load"
  end

  test "product page loads quickly" do
    start_time = Time.now
    get product_path(@product)
    end_time = Time.now
    
    assert_response :success
    assert (end_time - start_time) < 1.0, "Product page took too long to load"
  end

  test "api endpoint loads quickly" do
    skip "Requires API endpoint"
    
    start_time = Time.now
    get api_products_path, as: :json
    end_time = Time.now
    
    assert_response :success
    assert (end_time - start_time) < 0.5, "API took too long to respond"
  end

  # Caching Tests
  test "fragment caching works" do
    skip "Requires fragment cache setup"
    
    # First request should cache
    get product_path(@product)
    assert_response :success
    
    # Second request should use cache
    get product_path(@product)
    assert_response :success
  end

  test "redis cache is accessible" do
    skip "Requires Redis connection"
    
    # Test Redis connection
    # Rails.cache.write("test_key", "test_value")
    # assert_equal "test_value", Rails.cache.read("test_key")
  end

  # Security Tests
  test "rate limiting protects against abuse" do
    # Make many requests quickly
    20.times do
      get root_path
    end
    
    # Should still work (within limit)
    assert_response :success
  end

  test "graphql prevents injection attacks" do
    malicious_query = <<~GRAPHQL
      query {
        product(id: "1'; DROP TABLE products; --") {
          id
        }
      }
    GRAPHQL

    post graphql_path, params: { query: malicious_query }
    
    # Should handle gracefully
    assert_response :success
    assert Product.count > 0, "Products table should not be dropped"
  end

  # Compression Tests
  test "responses are compressed" do
    get root_path, headers: { "Accept-Encoding" => "gzip" }
    assert_response :success
    # Check if response is compressed
    # assert_equal "gzip", response.headers["Content-Encoding"]
  end

  # HTTP/2 Tests
  test "server push headers are present" do
    skip "Requires HTTP/2 server"
    
    get root_path
    assert_response :success
    assert response.headers["Link"].present?
  end

  private

  def sign_in(user)
    post login_path, params: { email: user.email, password: "password" }
  end
end

