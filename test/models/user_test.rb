# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.new(
      name: "Test User",
      email: "test@example.com",
      password: "SecurePass123!",
      password_confirmation: "SecurePass123!"
    )
  end

  # === Basic Validations ===
  
  test "should be valid with valid attributes" do
    assert @user.valid?
  end

  test "name should be present" do
    @user.name = "   "
    assert_not @user.valid?
  end

  test "email should be present" do
    @user.email = "   "
    assert_not @user.valid?
  end

  test "name should not be too long" do
    @user.name = "a" * 51
    assert_not @user.valid?
  end

  test "email should not be too long" do
    @user.email = "a" * 244 + "@example.com"
    assert_not @user.valid?
  end

  test "email validation should accept valid addresses" do
    valid_addresses = %w[
      user@example.com
      USER@foo.COM
      A_US-ER@foo.bar.org
      first.last@foo.jp
      alice+bob@baz.cn
    ]
    
    valid_addresses.each do |valid_address|
      @user.email = valid_address
      assert @user.valid?, "#{valid_address.inspect} should be valid"
    end
  end

  test "email validation should reject invalid addresses" do
    invalid_addresses = %w[
      user@example,com
      user_at_foo.org
      user.name@example.
      foo@bar_baz.com
      foo@bar+baz.com
    ]
    
    invalid_addresses.each do |invalid_address|
      @user.email = invalid_address
      assert_not @user.valid?, "#{invalid_address.inspect} should be invalid"
    end
  end

  test "email addresses should be unique" do
    duplicate_user = @user.dup
    duplicate_user.email = @user.email.upcase
    @user.save
    assert_not duplicate_user.valid?
  end

  test "email addresses should be saved as lower-case" do
    mixed_case_email = "Foo@ExAMPle.CoM"
    @user.email = mixed_case_email
    @user.save
    assert_equal mixed_case_email.downcase, @user.reload.email
  end

  # === Password Security Tests ===

  test "password should be present (non-blank)" do
    @user.password = @user.password_confirmation = " " * 8
    assert_not @user.valid?
  end

  test "password should have a minimum length of 8" do
    @user.password = @user.password_confirmation = "Abc123!"
    assert_not @user.valid?
  end

  test "password should not exceed 128 characters" do
    @user.password = @user.password_confirmation = "A1!" + ("a" * 126)
    assert_not @user.valid?
  end

  test "password should require uppercase letter" do
    @user.password = @user.password_confirmation = "securepass123!"
    assert_not @user.valid?
  end

  test "password should require lowercase letter" do
    @user.password = @user.password_confirmation = "SECUREPASS123!"
    assert_not @user.valid?
  end

  test "password should require number" do
    @user.password = @user.password_confirmation = "SecurePass!"
    assert_not @user.valid?
  end

  test "password should require special character" do
    @user.password = @user.password_confirmation = "SecurePass123"
    assert_not @user.valid?
  end

  test "password should reject common passwords" do
    common_passwords = %w[
      Password123!
      Welcome123!
      Admin123!
      Qwerty123!
    ]
    
    common_passwords.each do |common_pass|
      @user.password = @user.password_confirmation = common_pass
      assert_not @user.valid?, "#{common_pass.inspect} should be rejected as common"
    end
  end

  test "password should reject sequential patterns" do
    sequential_passwords = [
      "Abc12345!",    # Sequential numbers
      "Abcdefgh1!",   # Sequential letters
      "Qwerty123!",   # Keyboard pattern
      "Aaa12345!",    # Repeated characters
    ]
    
    sequential_passwords.each do |seq_pass|
      @user.password = @user.password_confirmation = seq_pass
      assert_not @user.valid?, "#{seq_pass.inspect} should be rejected as sequential"
    end
  end

  test "password should not contain email username" do
    @user.email = "testuser@example.com"
    @user.password = @user.password_confirmation = "Testuser123!"
    assert_not @user.valid?
  end

  test "strong passwords should be accepted" do
    strong_passwords = [
      "MyC0mpl3x!Pass",
      "Tr0pic@lStorm99",
      "B1u3M00n$h1ne",
      "C0ffee&Cream#7"
    ]
    
    strong_passwords.each do |strong_pass|
      @user.password = @user.password_confirmation = strong_pass
      assert @user.valid?, "#{strong_pass.inspect} should be valid"
    end
  end

  test "password strength calculation" do
    # Weak password
    weak_strength = User.password_strength("Pass123!")
    assert weak_strength < 70, "Weak password should score < 70"
    
    # Strong password
    strong_strength = User.password_strength("MyC0mpl3x!PassW0rd#2024")
    assert strong_strength >= 80, "Strong password should score >= 80"
  end

  # === Account Security Tests ===

  test "should record failed login attempts" do
    user = users(:one) # Using fixture
    initial_attempts = user.failed_login_attempts || 0
    
    user.record_failed_login!
    assert_equal initial_attempts + 1, user.failed_login_attempts
  end

  test "should lock account after 5 failed attempts" do
    user = users(:one)
    
    5.times { user.record_failed_login! }
    
    assert user.account_locked?
    assert user.locked_until > Time.current
  end

  test "should reset failed attempts on successful login" do
    user = users(:one)
    user.update_column(:failed_login_attempts, 3)
    
    user.record_successful_login!
    
    assert_equal 0, user.reload.failed_login_attempts
    assert_nil user.locked_until
  end

  # === Cart Operations Tests (Race Condition Protection) ===

  test "add_to_cart should create new cart item" do
    user = users(:one)
    product = products(:one)
    
    cart_item = user.add_to_cart(product, 2)
    
    assert_equal 2, cart_item.quantity
    assert_equal product, cart_item.item
  end

  test "add_to_cart should update existing cart item" do
    user = users(:one)
    product = products(:one)
    
    user.add_to_cart(product, 2)
    cart_item = user.add_to_cart(product, 3)
    
    assert_equal 5, cart_item.quantity
  end

  test "add_to_cart should handle concurrent requests" do
    user = users(:one)
    product = products(:one)
    
    threads = []
    5.times do
      threads << Thread.new do
        user.add_to_cart(product, 1)
      end
    end
    
    threads.each(&:join)
    
    # Should have exactly one cart item with quantity 5
    cart_items = user.cart_items.where(item: product)
    assert_equal 1, cart_items.count
    assert_equal 5, cart_items.first.quantity
  end

  # === User Type & Role Tests ===

  test "should default to seeker user type" do
    new_user = User.new(name: "New User", email: "new@example.com", password: "SecurePass123!")
    assert_equal 'seeker', new_user.user_type
  end

  test "should default to not_applied seller status" do
    new_user = User.new(name: "New User", email: "new@example.com", password: "SecurePass123!")
    assert_equal 'not_applied', new_user.seller_status
  end

  test "gem user with approved status can sell" do
    @user.user_type = 'gem'
    @user.seller_status = 'approved'
    assert @user.can_sell?
  end

  test "seeker user cannot sell" do
    @user.user_type = 'seeker'
    @user.seller_status = 'approved'
    assert_not @user.can_sell?
  end

  # === Gamification Tests ===

  test "should track login streak" do
    user = users(:one)
    user.update_login_streak!
    
    assert_equal 1, user.current_login_streak
    assert_equal 1, user.longest_login_streak
  end

  test "should increment consecutive login streak" do
    user = users(:one)
    user.update!(last_login_date: Date.current - 1.day, current_login_streak: 5)
    
    user.update_login_streak!
    
    assert_equal 6, user.current_login_streak
  end

  test "should reset broken login streak" do
    user = users(:one)
    user.update!(last_login_date: Date.current - 3.days, current_login_streak: 10, longest_login_streak: 15)
    
    user.update_login_streak!
    
    assert_equal 1, user.current_login_streak
    assert_equal 15, user.longest_login_streak # Should preserve longest
  end
end