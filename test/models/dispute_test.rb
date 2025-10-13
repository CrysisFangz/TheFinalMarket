# frozen_string_literal: true

require 'test_helper'

class DisputeTest < ActiveSupport::TestCase
  def setup
    @buyer = users(:one)
    @seller = users(:two)
    @moderator = users(:three)
    @order = orders(:one)
    @escrow_transaction = escrow_transactions(:one)

    @dispute = Dispute.new(
      order: @order,
      buyer: @buyer,
      seller: @seller,
      title: "Product not as described",
      description: "The product I received is completely different from what was advertised. It doesn't match the description or images at all.",
      amount: 99.99,
      dispute_type: :not_as_described
    )
  end

  # === Basic Validations ===

  test "should be valid with valid attributes" do
    assert @dispute.valid?
  end

  test "title should be present" do
    @dispute.title = nil
    assert_not @dispute.valid?
  end

  test "title should be at least 5 characters" do
    @dispute.title = "Hi"
    assert_not @dispute.valid?
  end

  test "title should not be too long" do
    @dispute.title = "a" * 101
    assert_not @dispute.valid?
  end

  test "description should be present" do
    @dispute.description = nil
    assert_not @dispute.valid?
  end

  test "description should be at least 20 characters" do
    @dispute.description = "Short description"
    assert_not @dispute.valid?
  end

  test "description should not be too long" do
    @dispute.description = "a" * 1001
    assert_not @dispute.valid?
  end

  test "amount should be present" do
    @dispute.amount = nil
    assert_not @dispute.valid?
  end

  test "amount should be greater than zero" do
    @dispute.amount = 0
    assert_not @dispute.valid?

    @dispute.amount = -10.00
    assert_not @dispute.valid?
  end

  test "dispute_type should be present" do
    @dispute.dispute_type = nil
    assert_not @dispute.valid?
  end

  # === Status Enum ===

  test "should have correct status values" do
    assert_equal 0, Dispute.statuses[:pending]
    assert_equal 1, Dispute.statuses[:under_review]
    assert_equal 2, Dispute.statuses[:resolved]
    assert_equal 3, Dispute.statuses[:dismissed]
    assert_equal 4, Dispute.statuses[:refunded]
    assert_equal 5, Dispute.statuses[:partially_refunded]
  end

  test "should default to pending status" do
    @dispute.save
    assert_equal 'pending', @dispute.status
  end

  test "should allow status changes" do
    @dispute.save

    @dispute.under_review!
    assert_equal 'under_review', @dispute.status

    @dispute.resolved!
    assert_equal 'resolved', @dispute.status

    @dispute.dismissed!
    assert_equal 'dismissed', @dispute.status
  end

  # === Dispute Type Enum ===

  test "should have correct dispute_type values" do
    assert_equal 0, Dispute.dispute_types[:non_delivery]
    assert_equal 1, Dispute.dispute_types[:quality_issues]
    assert_equal 2, Dispute.dispute_types[:not_as_described]
    assert_equal 3, Dispute.dispute_types[:damaged_in_transit]
    assert_equal 4, Dispute.dispute_types[:other]
  end

  test "should allow different dispute types" do
    @dispute.dispute_type = :non_delivery
    assert @dispute.valid?

    @dispute.dispute_type = :quality_issues
    assert @dispute.valid?

    @dispute.dispute_type = :damaged_in_transit
    assert @dispute.valid?

    @dispute.dispute_type = :other
    assert @dispute.valid?
  end

  # === Associations ===

  test "should belong to order" do
    assert_respond_to @dispute, :order
    assert_equal @order, @dispute.order
  end

  test "should belong to buyer" do
    assert_respond_to @dispute, :buyer
    assert_equal @buyer, @dispute.buyer
  end

  test "should belong to seller" do
    assert_respond_to @dispute, :seller
    assert_equal @seller, @dispute.seller
  end

  test "should belong to moderator optionally" do
    assert_respond_to @dispute, :moderator
    assert_nil @dispute.moderator
  end

  test "should belong to escrow_transaction optionally" do
    assert_respond_to @dispute, :escrow_transaction
  end

  test "should have many comments" do
    dispute = disputes(:one)
    assert_respond_to dispute, :comments
  end

  test "should have many evidences" do
    dispute = disputes(:one)
    assert_respond_to dispute, :evidences
  end

  test "should have one resolution" do
    dispute = disputes(:one)
    assert_respond_to dispute, :resolution
  end

  # === Scopes ===

  test "unassigned scope should return disputes without moderator" do
    scope = Dispute.unassigned
    assert_equal scope.to_sql, Dispute.where(moderator: nil).to_sql
  end

  test "active scope should return disputes not in final states" do
    scope = Dispute.active
    expected_sql = Dispute.where.not(status: [:resolved, :dismissed, :refunded, :partially_refunded]).to_sql
    assert_equal scope.to_sql, expected_sql
  end

  test "needs_review scope should return disputes under review" do
    scope = Dispute.needs_review
    assert_equal scope.to_sql, Dispute.where(status: :under_review).to_sql
  end

  test "pending_resolution scope should return disputes pending or under review" do
    scope = Dispute.pending_resolution
    assert_equal scope.to_sql, Dispute.where(status: [:pending, :under_review]).to_sql
  end

  # === Business Logic Methods ===

  test "can_participate? should return true for involved users" do
    @dispute.save

    assert @dispute.can_participate?(@buyer)
    assert @dispute.can_participate?(@seller)
    assert_not @dispute.can_participate?(users(:three))
  end

  test "can_participate? should return true for moderator when assigned" do
    @dispute.save
    @dispute.update(moderator: @moderator)

    assert @dispute.can_participate?(@moderator)
  end

  # === Callbacks ===

  test "should freeze escrow transaction after creation" do
    @dispute.save

    assert_equal 'disputed', @dispute.escrow_transaction.status
  end

  test "should notify parties after creation" do
    NotificationService.expects(:notify).with(
      user: @buyer,
      title: "Dispute Opened",
      message: "A dispute has been opened for order ##{@order.id}",
      resource: @dispute
    )
    NotificationService.expects(:notify).with(
      user: @seller,
      title: "Dispute Opened",
      message: "A dispute has been opened for order ##{@order.id}",
      resource: @dispute
    )

    @dispute.save
  end

  test "should notify status change after update" do
    @dispute.save

    NotificationService.expects(:notify).with(
      user: @buyer,
      title: "Dispute Status Updated",
      message: "Dispute status changed to: under_review",
      resource: @dispute
    )
    NotificationService.expects(:notify).with(
      user: @seller,
      title: "Dispute Status Updated",
      message: "Dispute status changed to: under_review",
      resource: @dispute
    )

    @dispute.update(status: :under_review)
  end

  # === Moderator Assignment ===

  test "assign_to_moderator should assign moderator and update status" do
    @dispute.save

    # Mock moderator with can_moderate_disputes? method
    moderator = mock('moderator')
    moderator.expects(:can_moderate_disputes?).returns(true)

    result = @dispute.assign_to_moderator(moderator)

    assert result
    assert_equal moderator, @dispute.moderator
    assert_equal 'under_review', @dispute.status
    assert_not_nil @dispute.moderator_assigned_at
  end

  test "assign_to_moderator should fail for non-moderator user" do
    @dispute.save

    user = mock('user')
    user.expects(:can_moderate_disputes?).returns(false)

    result = @dispute.assign_to_moderator(user)

    assert_not result
    assert_nil @dispute.moderator
    assert_equal 'pending', @dispute.status
  end

  test "assign_to_moderator should notify parties of assignment" do
    @dispute.save

    moderator = mock('moderator')
    moderator.expects(:can_moderate_disputes?).returns(true)

    NotificationService.expects(:notify).with(
      user: @buyer,
      title: "Moderator Assigned",
      message: "A moderator has been assigned to your dispute",
      resource: @dispute
    )
    NotificationService.expects(:notify).with(
      user: @seller,
      title: "Moderator Assigned",
      message: "A moderator has been assigned to your dispute",
      resource: @dispute
    )

    @dispute.assign_to_moderator(moderator)
  end

  test "assign_to_moderator should create activity record" do
    @dispute.save

    moderator = mock('moderator')
    moderator.expects(:can_moderate_disputes?).returns(true)

    @dispute.assign_to_moderator(moderator)

    activity = DisputeActivity.last
    assert_equal @dispute, activity.dispute
    assert_equal moderator, activity.user
    assert_equal 'moderator_assigned', activity.action
  end

  # === Evidence Management ===

  test "add_evidence should create evidence for valid user" do
    @dispute.save

    evidence_params = {
      title: "Photo evidence",
      description: "Photo showing the actual product received",
      attachment: "photo.jpg"
    }

    result = @dispute.add_evidence(@buyer, evidence_params)

    assert result
    assert_equal 1, @dispute.evidences.count

    evidence = @dispute.evidences.first
    assert_equal @buyer, evidence.user
    assert_equal evidence_params[:title], evidence.title
    assert_equal evidence_params[:description], evidence.description
  end

  test "add_evidence should fail for unauthorized user" do
    @dispute.save

    unauthorized_user = users(:three)
    evidence_params = {
      title: "Unauthorized evidence",
      description: "This should not be allowed",
      attachment: "unauthorized.jpg"
    }

    result = @dispute.add_evidence(unauthorized_user, evidence_params)

    assert_not result
    assert_equal 0, @dispute.evidences.count
  end

  test "add_evidence should create activity record" do
    @dispute.save

    evidence_params = {
      title: "Test evidence",
      description: "Test description",
      attachment: "test.jpg"
    }

    @dispute.add_evidence(@buyer, evidence_params)

    activity = DisputeActivity.last
    assert_equal @dispute, activity.dispute
    assert_equal @buyer, activity.user
    assert_equal 'evidence_added', activity.action
  end

  test "add_evidence should notify other parties" do
    @dispute.save

    NotificationService.expects(:notify).with(
      user: @seller,
      title: "New Evidence Added",
      message: "New evidence has been added to the dispute",
      resource: kind_of(DisputeEvidence)
    )

    evidence_params = {
      title: "Test evidence",
      description: "Test description",
      attachment: "test.jpg"
    }

    @dispute.add_evidence(@buyer, evidence_params)
  end

  # === Dispute Resolution ===

  test "resolve should create resolution and update status" do
    @dispute.save
    @dispute.update(moderator: @moderator)

    resolution_params = {
      resolution_type: 'refunded',
      refund_amount: 99.99,
      notes: 'Product was not as described'
    }

    # Mock escrow transaction methods
    @dispute.escrow_transaction.expects(:refund).with(99.99, admin_approved: true)

    result = @dispute.resolve(resolution_params)

    assert result
    assert_equal 'refunded', @dispute.status
    assert_not_nil @dispute.resolved_at
    assert_not_nil @dispute.resolution
  end

  test "resolve should handle partial refund" do
    @dispute.save
    @dispute.update(moderator: @moderator)

    resolution_params = {
      resolution_type: 'partially_refunded',
      refund_amount: 50.00,
      notes: 'Partial refund due to partial satisfaction'
    }

    @dispute.escrow_transaction.expects(:refund).with(50.00, admin_approved: true)

    result = @dispute.resolve(resolution_params)

    assert result
    assert_equal 'partially_refunded', @dispute.status
  end

  test "resolve should handle full release" do
    @dispute.save
    @dispute.update(moderator: @moderator)

    resolution_params = {
      resolution_type: 'resolved',
      refund_amount: 0,
      notes: 'Dispute resolved in favor of seller'
    }

    @dispute.escrow_transaction.expects(:release_funds).with(admin_approved: true)

    result = @dispute.resolve(resolution_params)

    assert result
    assert_equal 'resolved', @dispute.status
  end

  test "resolve should fail when dispute cannot be resolved" do
    @dispute.save
    # No moderator assigned

    resolution_params = {
      resolution_type: 'refunded',
      refund_amount: 99.99,
      notes: 'Should not work'
    }

    result = @dispute.resolve(resolution_params)

    assert_not result
    assert_equal 'pending', @dispute.status
    assert_nil @dispute.resolution
  end

  test "resolve should notify parties of resolution" do
    @dispute.save
    @dispute.update(moderator: @moderator)

    resolution_params = {
      resolution_type: 'refunded',
      refund_amount: 99.99,
      notes: 'Test resolution notes'
    }

    @dispute.escrow_transaction.stubs(:refund)

    NotificationService.expects(:notify).with(
      user: @buyer,
      title: "Dispute Resolved",
      message: "Your dispute has been resolved. Resolution: Test resolution notes",
      resource: @dispute
    )
    NotificationService.expects(:notify).with(
      user: @seller,
      title: "Dispute Resolved",
      message: "Your dispute has been resolved. Resolution: Test resolution notes",
      resource: @dispute
    )

    @dispute.resolve(resolution_params)
  end

  test "resolve should create activity record" do
    @dispute.save
    @dispute.update(moderator: @moderator)

    resolution_params = {
      resolution_type: 'refunded',
      refund_amount: 99.99,
      notes: 'Test resolution'
    }

    @dispute.escrow_transaction.stubs(:refund)

    @dispute.resolve(resolution_params)

    activity = DisputeActivity.last
    assert_equal @dispute, activity.dispute
    assert_equal @moderator, activity.user
    assert_equal 'resolved', activity.action
    assert_equal 'refunded', activity.data['resolution_type']
    assert_equal 99.99, activity.data['refund_amount']
  end

  # === Edge Cases and Error Handling ===

  test "should handle missing order gracefully" do
    dispute = Dispute.new(
      buyer: @buyer,
      seller: @seller,
      title: "Test dispute",
      description: "Test description with enough characters to pass validation",
      amount: 10.00,
      dispute_type: :other
    )

    assert_not dispute.valid?
    assert_includes dispute.errors[:order], "must exist"
  end

  test "should handle very large amounts" do
    @dispute.amount = 999999.99
    assert @dispute.valid?
  end

  test "should handle special characters in title and description" do
    @dispute.title = "Dispute with Spëcial Châractérs & Symbols!"
    @dispute.description = "Description with émojis 🚀 and spëcial châractérs"
    assert @dispute.valid?
  end

  test "should handle concurrent status updates safely" do
    @dispute.save

    threads = []
    5.times do
      threads << Thread.new do
        @dispute.update(status: :under_review)
      end
    end

    threads.each(&:join)

    # Should end up in a consistent state
    assert Dispute.statuses.keys.include?(@dispute.status.to_sym)
  end

  # === Performance Considerations ===

  test "should not create N+1 queries for associations" do
    dispute = disputes(:one)

    # Preload associations to avoid N+1 queries
    assert_sql_queries(1) do
      dispute.comments.to_a
      dispute.evidences.to_a
    end
  end

  test "should handle large number of comments and evidences efficiently" do
    @dispute.save

    # Create many comments and evidences
    50.times do |i|
      @dispute.comments.create!(
        user: @buyer,
        content: "Comment #{i}"
      )
      @dispute.evidences.create!(
        user: @buyer,
        title: "Evidence #{i}",
        description: "Description #{i}"
      )
    end

    # Should handle large datasets efficiently
    assert_equal 50, @dispute.comments.count
    assert_equal 50, @dispute.evidences.count
  end

  # === Integration with External Services ===

  test "should integrate properly with notification service" do
    NotificationService.expects(:notify).at_least_once

    @dispute.save
  end

  test "should handle notification service failures gracefully" do
    NotificationService.stubs(:notify).raises(StandardError.new("Notification failed"))

    # Should not prevent dispute creation
    assert_nothing_raised do
      @dispute.save
    end

    assert @dispute.persisted?
  end

  # === Business Rules Validation ===

  test "should not allow resolution without moderator" do
    @dispute.save

    resolution_params = {
      resolution_type: 'refunded',
      refund_amount: 99.99,
      notes: 'Should not work'
    }

    result = @dispute.resolve(resolution_params)

    assert_not result
    assert_nil @dispute.resolution
  end

  test "should not allow evidence from unauthorized users" do
    @dispute.save

    unauthorized_user = users(:three)
    evidence_params = {
      title: "Unauthorized evidence",
      description: "This should not be allowed",
      attachment: "unauthorized.jpg"
    }

    result = @dispute.add_evidence(unauthorized_user, evidence_params)

    assert_not result
    assert_equal 0, @dispute.evidences.count
  end

  # === State Machine Behavior ===

  test "should maintain proper state transitions" do
    @dispute.save

    # Valid progression
    assert @dispute.under_review!
    assert @dispute.resolved!

    # Should not allow invalid direct status assignment
    @dispute.status = 'invalid_status'
    assert_not @dispute.valid?
  end

  # === Data Integrity ===

  test "should maintain referential integrity with order" do
    @dispute.save

    # Dispute should reference order
    assert_equal @order, @dispute.order

    # Order should be able to access dispute
    assert_equal @dispute, @order.dispute
  end

  test "should maintain referential integrity with users" do
    @dispute.save

    # Dispute should reference correct users
    assert_equal @buyer, @dispute.buyer
    assert_equal @seller, @dispute.seller

    # Users should be able to access their disputes
    assert_includes @buyer.disputes_as_buyer, @dispute
    assert_includes @seller.disputes_as_seller, @dispute
  end

  # === Activity Tracking ===

  test "should create activity records for important actions" do
    @dispute.save

    # Assign moderator
    moderator = mock('moderator')
    moderator.expects(:can_moderate_disputes?).returns(true)
    @dispute.assign_to_moderator(moderator)

    # Add evidence
    evidence_params = {
      title: "Test evidence",
      description: "Test description",
      attachment: "test.jpg"
    }
    @dispute.add_evidence(@buyer, evidence_params)

    # Resolve dispute
    @dispute.update(moderator: @moderator)
    @dispute.escrow_transaction.stubs(:refund)
    @dispute.resolve(resolution_params = {
      resolution_type: 'refunded',
      refund_amount: 99.99,
      notes: 'Test resolution'
    })

    # Should have created activity records
    activities = DisputeActivity.where(dispute: @dispute)
    assert_equal 3, activities.count

    actions = activities.pluck(:action)
    assert_includes actions, 'moderator_assigned'
    assert_includes actions, 'evidence_added'
    assert_includes actions, 'resolved'
  end

  # === Fixture Integration ===

  test "should work with existing fixtures" do
    dispute = disputes(:one)
    assert_not_nil dispute.order
    assert_not_nil dispute.buyer
    assert_not_nil dispute.seller
    assert dispute.valid?
  end
end
