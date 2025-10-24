require 'test_helper'

class UserCurrencyPreferenceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @currency = currencies(:one)
  end

  test "should be valid with valid attributes" do
    preference = UserCurrencyPreference.new(user: @user, currency: @currency)
    assert preference.valid?
  end

  test "should require user" do
    preference = UserCurrencyPreference.new(currency: @currency)
    assert_not preference.valid?
    assert_includes preference.errors[:user], "can't be blank"
  end

  test "should require currency" do
    preference = UserCurrencyPreference.new(user: @user)
    assert_not preference.valid?
    assert_includes preference.errors[:currency], "can't be blank"
  end

  test "should enforce uniqueness of user_id" do
    UserCurrencyPreference.create!(user: @user, currency: @currency)
    duplicate = UserCurrencyPreference.new(user: @user, currency: @currency)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "should validate currency is active" do
    inactive_currency = currencies(:two) # Assuming :two is inactive
    preference = UserCurrencyPreference.new(user: @user, currency: inactive_currency)
    assert_not preference.valid?
    assert_includes preference.errors[:currency], "must be active"
  end

  test "should return currency code" do
    preference = UserCurrencyPreference.new(user: @user, currency: @currency)
    assert_equal @currency.code, preference.currency_code
  end
end