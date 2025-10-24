require "test_helper"

class UserReputationEventTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @event = UserReputationEvent.new(user: @user, points: 10, reason: "Good review")
  end

  test "should be valid with valid attributes" do
    assert @event.valid?
  end

  test "should not be valid without points" do
    @event.points = nil
    assert_not @event.valid?
  end

  test "should not be valid with non-integer points" do
    @event.points = 10.5
    assert_not @event.valid?
  end

  test "should not be valid without reason" do
    @event.reason = nil
    assert_not @event.valid?
  end

  test "should not be valid with reason too long" do
    @event.reason = "a" * 256
    assert_not @event.valid?
  end

  test "should belong to user" do
    assert_respond_to @event, :user
  end

  test "should have scopes" do
    assert_respond_to UserReputationEvent, :by_user
    assert_respond_to UserReputationEvent, :recent
    assert_respond_to UserReputationEvent, :positive_points
    assert_respond_to UserReputationEvent, :negative_points
  end

  test "should have positive? method" do
    @event.points = 10
    assert @event.positive?
    @event.points = -10
    assert_not @event.positive?
  end

  test "should have negative? method" do
    @event.points = -10
    assert @event.negative?
    @event.points = 10
    assert_not @event.negative?
  end

  test "should prevent updates to points and reason" do
    @event.save!
    original_points = @event.points
    original_reason = @event.reason
    @event.points = 20
    @event.reason = "Updated reason"
    assert_not @event.valid?
    assert_includes @event.errors[:base], "Cannot update points or reason after creation"
  end
end
