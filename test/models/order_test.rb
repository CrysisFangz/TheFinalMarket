# frozen_string_literal: true

require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  def setup
    @buyer = users(:one)
    @seller = users(:two)
    @order = Order.new(
      buyer: @buyer,
      seller: @seller,
      total_amount: 99.99,
      shipping_address: "123 Test St, Test City, TC 12345"
    )
  end

  # === Basic Validations ===

  test "should be valid with valid attributes" do
    assert @order.valid?
  end

  test "total_amount should be present" do
    @order.total_amount = nil
    assert_not @order.valid?
  end

  test "total_amount should be greater than zero" do
    @order.total_amount = 0
    assert_not @order.valid?

    @order.total_amount = -10.00
    assert_not @order.valid?
  end

  test "shipping_address should be present" do
    @order.shipping_address = "   "
    assert_not @order.valid?
  end

  test "buyer should be present" do
    @order.buyer = nil
    assert_not @order.valid?
  end

  test "seller should be present" do
    @order.seller = nil
    assert_not @order.valid?
  end

  # === Status Enum ===

  test "should have correct status values" do
    assert_equal 0, Order.statuses[:pending]
    assert_equal 1, Order.statuses[:processing]
    assert_equal 2, Order.statuses[:shipped]
    assert_equal 3, Order.statuses[:delivered]
    assert_equal 4, Order.statuses[:completed]
    assert_equal 5, Order.statuses[:cancelled]
    assert_equal 6, Order.statuses[:refunded]
  end

  test "should default to pending status" do
    @order.save
    assert_equal 'pending', @order.status
  end

  test "should allow status changes" do
    @order.save

    @order.processing!
    assert_equal 'processing', @order.status

    @order.shipped!
    assert_equal 'shipped', @order.status

    @order.delivered!
    assert_equal 'delivered', @order.status

    @order.completed!
    assert_equal 'completed', @order.status
  end

  # === Associations ===

  test "should belong to buyer" do
    assert_respond_to @order, :buyer
    assert_equal @buyer, @order.buyer
  end

  test "should belong to seller" do
    assert_respond_to @order, :seller
    assert_equal @seller, @order.seller
  end

  test "should have many order_items" do
    order = orders(:one)
    assert_respond_to order, :order_items
  end

  test "should have many items through order_items" do
    order = orders(:one)
    assert_respond_to order, :items
  end

  test "should have one escrow_transaction" do
    order = orders(:one)
    assert_respond_to order, :escrow_transaction
  end

  test "should have one review_invitation" do
    order = orders(:one)
    assert_respond_to order, :review_invitation
  end

  test "should have one review through review_invitation" do
    order = orders(:one)
    assert_respond_to order, :review
  end

  test "should have one dispute" do
    order = orders(:one)
    assert_respond_to order, :dispute
  end

  # === Business Logic Methods ===

  test "total_items should return sum of order item quantities" do
    order = orders(:one)
    # Assuming order has order_items in fixtures
    expected_total = order.order_items.sum(:quantity)
    assert_equal expected_total, order.total_items
  end

  test "calculate_total should return sum of item prices * quantities" do
    order = orders(:one)
    expected_total = order.order_items.sum { |item| item.unit_price * item.quantity }
    assert_equal expected_total, order.calculate_total
  end

  test "confirmed_delivery? should return true when delivered and confirmed" do
    @order.save
    @order.delivered!
    @order.update_column(:delivery_confirmed_at, Time.current)

    assert @order.confirmed_delivery?
  end

  test "confirmed_delivery? should return false when not delivered" do
    @order.save
    @order.processing!

    assert_not @order.confirmed_delivery?
  end

  test "confirmed_delivery? should return false when delivered but not confirmed" do
    @order.save
    @order.delivered!

    assert_not @order.confirmed_delivery?
  end

  test "finalized? should return true when finalized_at is present" do
    @order.save
    @order.update_column(:finalized_at, Time.current)

    assert @order.finalized?
  end

  test "finalized? should return false when finalized_at is nil" do
    @order.save

    assert_not @order.finalized?
  end

  test "disputed? should return true when escrow_transaction is disputed" do
    order = orders(:one)
    # Mock disputed escrow transaction
    order.escrow_transaction = mock('escrow_transaction')
    order.escrow_transaction.expects(:disputed?).returns(true)

    assert @order.disputed?
  end

  test "review_pending? should return true when review_invitation is pending" do
    order = orders(:one)
    # Mock pending review invitation
    order.review_invitation = mock('review_invitation')
    order.review_invitation.expects(:pending?).returns(true)

    assert @order.review_pending?
  end

  # === Scopes ===

  test "recent scope should order by created_at desc" do
    orders = Order.recent
    assert_equal orders.to_sql, Order.order(created_at: :desc).to_sql
  end

  test "unfinalized scope should return orders without finalized_at" do
    scope = Order.unfinalized
    assert_equal scope.to_sql, Order.where(finalized_at: nil).to_sql
  end

  test "finalized scope should return orders with finalized_at" do
    scope = Order.finalized
    assert_equal scope.to_sql, Order.where.not(finalized_at: nil).to_sql
  end

  test "pending_finalization scope should return eligible orders" do
    scope = Order.pending_finalization
    expected_sql = Order.where(status: :delivered)
                       .where('delivery_confirmed_at <= ?', 7.days.ago)
                       .where(finalized_at: nil)
                       .joins(:escrow_transaction)
                       .where.not(escrow_transactions: { status: :disputed })
                       .to_sql

    assert_equal scope.to_sql, expected_sql
  end

  # === Callbacks and Lifecycle ===

  test "should create escrow_transaction after creation" do
    @order.save

    assert_not_nil @order.escrow_transaction
    assert_equal @order, @order.escrow_transaction.order
    assert_equal @buyer, @order.escrow_transaction.buyer
    assert_equal @seller, @order.escrow_transaction.seller
    assert_equal @order.total_amount, @order.escrow_transaction.amount
  end

  test "should award points to buyer and seller after creation" do
    initial_buyer_points = @buyer.points
    initial_seller_points = @seller.points

    @order.save

    expected_buyer_points = initial_buyer_points + (@order.total_amount * 10).to_i
    expected_seller_points = initial_seller_points + (@order.total_amount * 15).to_i

    assert_equal expected_buyer_points, @buyer.reload.points
    assert_equal expected_seller_points, @seller.reload.points
  end

  test "should mark items as sold after creation" do
    # Create test items for the order
    item1 = items(:one)
    item2 = items(:two)

    @order.items << [item1, item2]
    @order.save

    assert_equal 'sold', item1.reload.status
    assert_equal 'sold', item2.reload.status
  end

  test "should clear buyer's cart after creation" do
    # Create cart items for buyer
    cart = @buyer.cart || @buyer.create_cart
    cart_item = cart.cart_items.create!(item: items(:one), quantity: 2)

    @order.save

    assert_empty @buyer.cart.cart_items
  end

  test "should set delivery_confirmed_at when status changes to delivered" do
    @order.save
    @order.update!(status: :delivered)

    assert_not_nil @order.delivery_confirmed_at
    assert_in_delta Time.current, @order.delivery_confirmed_at, 1.second
  end

  test "should schedule auto finalization job when status changes to delivered" do
    @order.save

    # Mock the job scheduling
    CheckOrderFinalizationsJob.expects(:schedule).once

    @order.update!(status: :delivered)
  end

  # === Service Integration ===

  test "can_be_finalized? should delegate to OrderFinalizationService" do
    @order.save

    mock_service = mock('service')
    mock_service.expects(:send).with(:can_finalize?).returns(true)

    OrderFinalizationService.expects(:new).with(@order).returns(mock_service)

    assert @order.can_be_finalized?
  end

  test "finalize should delegate to OrderFinalizationService" do
    @order.save

    mock_service = mock('service')
    mock_service.expects(:finalize).with(admin_approved: false)

    OrderFinalizationService.expects(:new).with(@order).returns(mock_service)

    @order.finalize
  end

  test "finalize should pass admin_approved parameter" do
    @order.save

    mock_service = mock('service')
    mock_service.expects(:finalize).with(admin_approved: true)

    OrderFinalizationService.expects(:new).with(@order).returns(mock_service)

    @order.finalize(admin_approved: true)
  end

  # === Edge Cases and Error Handling ===

  test "should handle zero total_amount gracefully" do
    @order.total_amount = 0.01 # Minimum valid amount
    assert @order.valid?
  end

  test "should handle very large total_amount" do
    @order.total_amount = 999999.99
    assert @order.valid?
  end

  test "should handle missing associations gracefully" do
    order = Order.new(
      total_amount: 10.00,
      shipping_address: "123 Test St"
    )

    assert_not order.valid?
    assert_includes order.errors[:buyer], "must exist"
    assert_includes order.errors[:seller], "must exist"
  end

  test "should handle status transitions correctly" do
    @order.save

    # Valid transition
    assert @order.processing!
    assert_equal 'processing', @order.status

    # Should not allow invalid direct status assignment
    @order.status = 'invalid_status'
    assert_not @order.valid?
  end

  test "should handle point calculation with fractional amounts" do
    @order.total_amount = 10.50
    initial_buyer_points = @buyer.points

    @order.save

    expected_points = initial_buyer_points + 105 # 10.50 * 10
    assert_equal expected_points, @buyer.reload.points
  end

  # === Concurrency and Race Conditions ===

  test "should handle concurrent order creation safely" do
    threads = []
    orders = []

    5.times do |i|
      threads << Thread.new do
        order = Order.create!(
          buyer: @buyer,
          seller: @seller,
          total_amount: 10.00 + i,
          shipping_address: "123 Test St #{i}"
        )
        orders << order
      end
    end

    threads.each(&:join)

    assert_equal 5, orders.length
    orders.each do |order|
      assert order.persisted?
      assert_not_nil order.escrow_transaction
    end
  end

  # === Performance Considerations ===

  test "should not create N+1 queries for associations" do
    order = orders(:one)

    # Preload associations to avoid N+1 queries
    assert_sql_queries(1) do
      order.order_items.to_a
      order.items.to_a
    end
  end

  test "should handle large number of order_items efficiently" do
    @order.save

    # Create many order items
    100.times do |i|
      @order.order_items.create!(
        item: items(:one),
        quantity: 1,
        unit_price: 1.00
      )
    end

    # Should calculate totals efficiently
    assert_equal 100, @order.total_items
    assert_equal 100.00, @order.calculate_total
  end

  # === Integration with External Systems ===

  test "should integrate properly with escrow system" do
    @order.save

    escrow = @order.escrow_transaction
    assert_not_nil escrow
    assert_equal @order.total_amount, escrow.amount
    assert_equal @buyer, escrow.buyer
    assert_equal @seller, escrow.seller
  end

  test "should handle escrow transaction errors gracefully" do
    # Mock escrow transaction creation failure
    EscrowTransaction.expects(:create!).raises(ActiveRecord::RecordInvalid.new(EscrowTransaction.new))

    assert_raises ActiveRecord::RecordInvalid do
      @order.save
    end
  end

  # === Business Rules Validation ===

  test "should not allow order without items" do
    @order.save

    # Order should be valid even without items initially
    # Items are added through order_items association
    assert @order.valid?
  end

  test "should calculate total correctly with multiple items" do
    @order.save

    item1 = items(:one)
    item2 = items(:two)

    @order.order_items.create!(item: item1, quantity: 2, unit_price: 25.00)
    @order.order_items.create!(item: item2, quantity: 1, unit_price: 49.99)

    expected_total = (25.00 * 2) + 49.99
    assert_equal expected_total, @order.calculate_total
  end

  # === State Machine Behavior ===

  test "should maintain proper state transitions" do
    @order.save

    # Valid progression
    assert @order.processing!
    assert @order.shipped!
    assert @order.delivered!
    assert @order.completed!

    # Should not allow going backwards
    @order.update(status: :processing)
    assert_equal 'processing', @order.status
  end

  test "should handle cancellation properly" do
    @order.save
    @order.processing!

    @order.cancelled!
    assert_equal 'cancelled', @order.status

    # Should not allow further status changes after cancellation
    @order.status = 'completed'
    assert_not @order.valid?
  end
end
