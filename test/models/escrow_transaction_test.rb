# frozen_string_literal: true

require 'test_helper'

class EscrowTransactionTest < ActiveSupport::TestCase
  def setup
    @buyer = users(:one)
    @seller = users(:two)
    @order = orders(:one)
    @escrow_wallet = escrow_wallets(:one)
    
    @transaction = EscrowTransaction.new(
      escrow_wallet: @escrow_wallet,
      order: @order,
      sender: @buyer,
      receiver: @seller,
      amount: 100.00,
      transaction_type: 'order_payment',
      status: :pending
    )
  end

  # === Basic Validations ===

  test "should be valid with valid attributes" do
    assert @transaction.valid?
  end

  test "amount should be present" do
    @transaction.amount = nil
    assert_not @transaction.valid?
  end

  test "amount should be greater than zero" do
    @transaction.amount = 0
    assert_not @transaction.valid?
    
    @transaction.amount = -10
    assert_not @transaction.valid?
  end

  test "status should be present" do
    @transaction.status = nil
    assert_not @transaction.valid?
  end

  test "transaction_type should be present" do
    @transaction.transaction_type = nil
    assert_not @transaction.valid?
  end

  test "sender and receiver should be different" do
    @transaction.receiver = @transaction.sender
    assert_not @transaction.valid?
    assert_includes @transaction.errors[:base], "Sender and receiver must be different users"
  end

  test "scheduled release date should be in future" do
    @transaction.scheduled_release_at = 1.day.ago
    assert_not @transaction.valid?
  end

  # === Release Funds Tests ===

  test "should release funds successfully" do
    @transaction.status = :held
    @escrow_wallet.update!(balance: 100.00)
    @seller.escrow_wallet.update!(balance: 0)
    
    result = @transaction.release_funds
    
    assert result
    assert @transaction.reload.released?
    assert_equal 100.00, @seller.escrow_wallet.reload.balance
  end

  test "should not release funds if not held" do
    @transaction.status = :pending
    
    result = @transaction.release_funds
    
    assert_not result
    assert_not @transaction.released?
  end

  test "should prevent duplicate release (idempotency)" do
    @transaction.status = :released
    @escrow_wallet.update!(balance: 0)
    initial_seller_balance = @seller.escrow_wallet.balance
    
    # Attempt second release
    result = @transaction.release_funds
    
    assert result # Should return true without error
    assert_equal initial_seller_balance, @seller.escrow_wallet.reload.balance # Balance unchanged
  end

  test "should verify sufficient balance before release" do
    @transaction.status = :held
    @escrow_wallet.update!(balance: 50.00) # Insufficient balance
    
    result = @transaction.release_funds
    
    assert_not result
    assert_includes @transaction.errors[:base], /Insufficient escrow balance/
  end

  test "should log release transaction" do
    @transaction.status = :held
    @transaction.save!
    @escrow_wallet.update!(balance: 100.00)
    
    assert_difference 'Rails.logger' do
      @transaction.release_funds
    end
  end

  # === Refund Tests ===

  test "should refund full amount successfully" do
    @transaction.status = :held
    @transaction.save!
    @escrow_wallet.update!(balance: 100.00)
    @buyer.escrow_wallet.update!(balance: 0)
    
    result = @transaction.refund
    
    assert result
    assert @transaction.reload.refunded?
    assert_equal 100.00, @buyer.escrow_wallet.reload.balance
  end

  test "should refund partial amount successfully" do
    @transaction.status = :held
    @transaction.save!
    @escrow_wallet.update!(balance: 100.00)
    @buyer.escrow_wallet.update!(balance: 0)
    
    result = @transaction.refund(60.00)
    
    assert result
    assert @transaction.reload.partially_refunded?
    assert_equal 60.00, @buyer.escrow_wallet.reload.balance
    assert_equal 60.00, @transaction.refunded_amount
  end

  test "should not refund if already refunded (idempotency)" do
    @transaction.status = :refunded
    @transaction.save!
    initial_buyer_balance = @buyer.escrow_wallet.balance
    
    result = @transaction.refund
    
    assert result # Should return true without error
    assert_equal initial_buyer_balance, @buyer.escrow_wallet.reload.balance
  end

  test "should validate refund amount" do
    @transaction.status = :held
    @transaction.save!
    @escrow_wallet.update!(balance: 100.00)
    
    # Test negative amount
    result = @transaction.refund(-10)
    assert_not result
    assert_includes @transaction.errors[:base], /Invalid refund amount/
    
    # Test amount exceeding transaction amount
    @transaction.errors.clear
    result = @transaction.refund(150)
    assert_not result
    assert_includes @transaction.errors[:base], /Invalid refund amount/
  end

  test "should verify sufficient balance before refund" do
    @transaction.status = :held
    @transaction.save!
    @escrow_wallet.update!(balance: 50.00) # Insufficient
    
    result = @transaction.refund(100.00)
    
    assert_not result
    assert_includes @transaction.errors[:base], /Insufficient escrow balance for refund/
  end

  # === Dispute Tests ===

  test "should initiate dispute successfully" do
    @transaction.status = :held
    @transaction.save!
    
    result = @transaction.initiate_dispute
    
    assert result
    assert @transaction.reload.disputed?
  end

  test "should not initiate duplicate dispute" do
    @transaction.status = :disputed
    @transaction.save!
    
    result = @transaction.initiate_dispute
    
    assert_not result
  end

  # === Status Change Logging ===

  test "should log status changes" do
    @transaction.save!
    
    assert_difference -> { Rails.logger } do
      @transaction.update!(status: :held)
    end
  end

  # === Scopes Tests ===

  test "pending_finalization scope should return old held transactions" do
    old_transaction = EscrowTransaction.create!(
      escrow_wallet: @escrow_wallet,
      order: @order,
      sender: @buyer,
      receiver: @seller,
      amount: 50,
      transaction_type: 'order_payment',
      status: :held,
      created_at: 10.days.ago
    )
    
    pending = EscrowTransaction.pending_finalization
    assert_includes pending, old_transaction
  end

  test "needs_admin_approval scope should return flagged transactions" do
    admin_transaction = EscrowTransaction.create!(
      escrow_wallet: @escrow_wallet,
      order: @order,
      sender: @buyer,
      receiver: @seller,
      amount: 1000,
      transaction_type: 'order_payment',
      status: :held,
      needs_admin_approval: true
    )
    
    flagged = EscrowTransaction.needs_admin_approval
    assert_includes flagged, admin_transaction
  end

  # === Concurrent Transaction Tests ===

  test "should handle concurrent release attempts safely" do
    @transaction.status = :held
    @transaction.save!
    @escrow_wallet.update!(balance: 100.00)
    @seller.escrow_wallet.update!(balance: 0)
    
    threads = []
    results = []
    
    3.times do
      threads << Thread.new do
        results << @transaction.release_funds
      end
    end
    
    threads.each(&:join)
    
    # First request should succeed, others should be idempotent
    assert results.any?, "At least one release should succeed"
    assert_equal 100.00, @seller.escrow_wallet.reload.balance
  end

  test "should handle concurrent refund attempts safely" do
    @transaction.status = :held
    @transaction.save!
    @escrow_wallet.update!(balance: 100.00)
    @buyer.escrow_wallet.update!(balance: 0)
    
    threads = []
    results = []
    
    3.times do
      threads << Thread.new do
        results << @transaction.refund
      end
    end
    
    threads.each(&:join)
    
    # Only one refund should actually process
    assert_equal 100.00, @buyer.escrow_wallet.reload.balance
    assert @transaction.reload.refunded?
  end
end