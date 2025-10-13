# frozen_string_literal: true

require 'test_helper'

class CartTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @cart = Cart.new(user: @user)
  end

  # === Basic Validations ===

  test "should be valid with valid attributes" do
    assert @cart.valid?
  end

  test "user should be present" do
    @cart.user = nil
    assert_not @cart.valid?
  end

  # === Associations ===

  test "should belong to user" do
    assert_respond_to @cart, :user
    assert_equal @user, @cart.user
  end

  test "should have many line_items" do
    cart = carts(:one)
    assert_respond_to cart, :line_items
  end

  test "should have many products through line_items" do
    cart = carts(:one)
    assert_respond_to cart, :products
  end

  test "should destroy line_items when cart is destroyed" do
    cart = carts(:one)
    line_item = cart.line_items.create!(
      product: products(:one),
      quantity: 2,
      unit_price: 25.00
    )

    assert_difference 'LineItem.count', -1 do
      cart.destroy
    end
  end

  # === Business Logic ===

  test "total_price should calculate sum of line item total prices" do
    cart = carts(:one)

    # Create test line items
    line_item1 = cart.line_items.create!(
      product: products(:one),
      quantity: 2,
      unit_price: 25.00
    )
    line_item2 = cart.line_items.create!(
      product: products(:two),
      quantity: 1,
      unit_price: 50.00
    )

    expected_total = (25.00 * 2) + 50.00
    assert_equal expected_total, cart.total_price
  end

  test "total_price should return zero for empty cart" do
    cart = carts(:one)
    assert_equal 0, cart.total_price
  end

  test "total_price should handle line items with zero quantity" do
    cart = carts(:one)
    cart.line_items.create!(
      product: products(:one),
      quantity: 0,
      unit_price: 25.00
    )

    assert_equal 0, cart.total_price
  end

  test "total_price should handle line items with zero unit_price" do
    cart = carts(:one)
    cart.line_items.create!(
      product: products(:one),
      quantity: 2,
      unit_price: 0
    )

    assert_equal 0, cart.total_price
  end

  # === Edge Cases ===

  test "should handle missing user gracefully" do
    cart = Cart.new
    assert_not cart.valid?
    assert_includes cart.errors[:user], "must exist"
  end

  test "should handle very large quantities" do
    cart = carts(:one)
    line_item = cart.line_items.create!(
      product: products(:one),
      quantity: 999999,
      unit_price: 0.01
    )

    # Should not cause overflow or performance issues
    total = cart.total_price
    assert total.finite?
    assert total > 0
  end

  test "should handle very large unit prices" do
    cart = carts(:one)
    line_item = cart.line_items.create!(
      product: products(:one),
      quantity: 1,
      unit_price: 999999.99
    )

    total = cart.total_price
    assert total.finite?
    assert_equal 999999.99, total
  end

  test "should handle fractional prices correctly" do
    cart = carts(:one)
    line_item = cart.line_items.create!(
      product: products(:one),
      quantity: 3,
      unit_price: 33.33
    )

    expected_total = 33.33 * 3
    assert_equal expected_total, cart.total_price
  end

  # === Performance and Memory ===

  test "should handle large number of line items efficiently" do
    cart = carts(:one)

    # Create many line items
    100.times do |i|
      cart.line_items.create!(
        product: products(:one),
        quantity: 1,
        unit_price: 10.00
      )
    end

    # Should calculate total efficiently
    total = cart.total_price
    assert_equal 1000.00, total
  end

  test "should not create N+1 queries for basic operations" do
    cart = carts(:one)

    # Preload associations to avoid N+1 queries
    assert_sql_queries(1) do
      cart.line_items.to_a
      cart.products.to_a
    end
  end

  # === Concurrency Safety ===

  test "should handle concurrent cart modifications safely" do
    cart = carts(:one)
    threads = []
    results = []

    5.times do |i|
      threads << Thread.new do
        line_item = cart.line_items.create!(
          product: products(:one),
          quantity: 1,
          unit_price: 10.00 + i
        )
        results << line_item
      end
    end

    threads.each(&:join)

    assert_equal 5, results.length
    assert_equal 5, cart.line_items.count

    # Total should be sum of all prices
    expected_total = (10.00 + 11.00 + 12.00 + 13.00 + 14.00)
    assert_equal expected_total, cart.total_price
  end

  # === Business Rules ===

  test "should allow multiple products in cart" do
    cart = carts(:one)

    product1 = products(:one)
    product2 = products(:two)

    line_item1 = cart.line_items.create!(
      product: product1,
      quantity: 2,
      unit_price: 25.00
    )
    line_item2 = cart.line_items.create!(
      product: product2,
      quantity: 1,
      unit_price: 50.00
    )

    assert_equal 2, cart.line_items.count
    assert_equal 2, cart.products.count
    assert_includes cart.products, product1
    assert_includes cart.products, product2
  end

  test "should allow same product multiple times" do
    cart = carts(:one)
    product = products(:one)

    line_item1 = cart.line_items.create!(
      product: product,
      quantity: 2,
      unit_price: 25.00
    )
    line_item2 = cart.line_items.create!(
      product: product,
      quantity: 3,
      unit_price: 25.00
    )

    assert_equal 2, cart.line_items.count
    assert_equal 1, cart.products.count
    assert_equal 5, cart.total_price # 25.00 * 5
  end

  # === Data Integrity ===

  test "should maintain referential integrity" do
    cart = carts(:one)
    product = products(:one)

    line_item = cart.line_items.create!(
      product: product,
      quantity: 2,
      unit_price: 25.00
    )

    # Cart should reference the line item
    assert_includes cart.line_items, line_item

    # Product should be accessible through cart
    assert_includes cart.products, product

    # Line item should reference both cart and product
    assert_equal cart, line_item.cart
    assert_equal product, line_item.product
  end

  # === Calculation Accuracy ===

  test "should calculate total price with precision" do
    cart = carts(:one)

    # Test with various price points
    prices = [19.99, 25.50, 33.33, 49.95]
    quantities = [1, 2, 3, 1]

    expected_total = 0
    prices.zip(quantities).each do |price, quantity|
      cart.line_items.create!(
        product: products(:one),
        quantity: quantity,
        unit_price: price
      )
      expected_total += price * quantity
    end

    calculated_total = cart.total_price
    assert_equal expected_total, calculated_total
    assert_equal 4, cart.line_items.count
  end

  test "should handle rounding correctly" do
    cart = carts(:one)

    # Create line items that might cause rounding issues
    cart.line_items.create!(
      product: products(:one),
      quantity: 3,
      unit_price: 33.33
    )

    total = cart.total_price
    # Should be exactly 99.99
    assert_equal 99.99, total
  end

  # === Memory Efficiency ===

  test "should not load unnecessary data" do
    cart = carts(:one)

    # Should not load associated products unless needed
    assert_sql_queries(1) do
      cart.line_items.to_a
    end

    # Should load products when accessing through association
    assert_sql_queries(2) do
      cart.products.to_a
    end
  end

  # === Error Handling ===

  test "should handle database errors gracefully" do
    cart = carts(:one)

    # Mock a database error during line item creation
    LineItem.expects(:create!).raises(ActiveRecord::RecordInvalid.new(LineItem.new))

    assert_raises ActiveRecord::RecordInvalid do
      cart.line_items.create!(
        product: products(:one),
        quantity: 2,
        unit_price: 25.00
      )
    end
  end

  # === Fixture Integration ===

  test "should work with existing fixtures" do
    cart = carts(:one)
    assert_not_nil cart.user
    assert cart.valid?
  end

  # === Edge Cases for Total Calculation ===

  test "should handle nil line items gracefully" do
    cart = carts(:one)

    # Manually set line_items to empty array to simulate edge case
    cart.line_items = []

    assert_equal 0, cart.total_price
  end

  test "should handle line items with nil total_price" do
    cart = carts(:one)

    line_item = cart.line_items.create!(
      product: products(:one),
      quantity: 2,
      unit_price: 25.00
    )

    # Mock the total_price method to return nil
    line_item.stubs(:total_price).returns(nil)

    # Should handle nil gracefully (skip or treat as 0)
    total = cart.total_price
    assert total.is_a?(Numeric)
  end
end
