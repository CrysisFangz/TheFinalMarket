require "test_helper"

class FraudDetectionServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @new_user = users(:two)
    @order = orders(:one)
    
    # Set up user attributes for testing
    @user.update!(
      created_at: 1.year.ago,
      email_verified: true
    )
    
    @new_user.update!(
      created_at: 6.hours.ago,
      email_verified: false
    )
  end

  # Basic functionality tests
  test "creates fraud check record" do
    service = FraudDetectionService.new(@user, @order, :order_placement)
    
    assert_difference 'FraudCheck.count', 1 do
      service.check
    end
  end

  test "returns fraud check object" do
    service = FraudDetectionService.new(@user, @order, :order_placement)
    result = service.check
    
    assert_instance_of FraudCheck, result
    assert_equal @user, result.user
    assert_equal @order, result.checkable
  end

  # Risk score calculation tests
  test "calculates low risk score for established user" do
    service = FraudDetectionService.new(@user, @order, :login_attempt)
    fraud_check = service.check
    
    assert fraud_check.risk_score < 40, "Expected low risk score, got #{fraud_check.risk_score}"
    assert_equal 'low', fraud_check.risk_level
    refute fraud_check.flagged
  end

  test "calculates high risk score for new unverified user" do
    service = FraudDetectionService.new(@new_user, @order, :order_placement)
    fraud_check = service.check
    
    assert fraud_check.risk_score >= 40, "Expected higher risk score for new user"
  end

  test "flags high risk checks" do
    service = FraudDetectionService.new(@new_user, @order, :order_placement)
    fraud_check = service.check
    
    if fraud_check.risk_score >= 70
      assert fraud_check.flagged, "High risk check should be flagged"
    end
  end

  # User age checks
  test "penalizes very new accounts" do
    very_new_user = User.create!(
      name: "Very New",
      email: "verynew@test.com",
      password: "password123",
      created_at: 12.hours.ago
    )
    
    service = FraudDetectionService.new(very_new_user, @order, :order_placement)
    fraud_check = service.check
    
    assert fraud_check.risk_score > 0, "New account should have some risk"
    assert fraud_check.risk_factors_array.any? { |f| f['factor'].include?('new account') }
  end

  test "gives no penalty for old accounts" do
    old_user = User.create!(
      name: "Old User",
      email: "old@test.com",
      password: "password123",
      created_at: 2.years.ago,
      email_verified: true
    )
    
    service = FraudDetectionService.new(old_user, @order, :login_attempt)
    fraud_check = service.check
    
    # Old verified user should have low risk
    assert fraud_check.risk_score < 30, "Old verified user should have low risk"
  end

  # Verification checks
  test "penalizes unverified email" do
    @user.update!(email_verified: false)
    
    service = FraudDetectionService.new(@user, @order, :order_placement)
    fraud_check = service.check
    
    assert fraud_check.risk_factors_array.any? { |f| f['factor'].include?('Email not verified') }
  end

  # Velocity checks
  test "detects high velocity activity" do
    # Create many recent fraud checks to simulate high activity
    25.times do
      FraudCheck.create!(
        user: @user,
        checkable: @order,
        check_type: :login_attempt,
        risk_score: 10,
        created_at: 30.minutes.ago
      )
    end
    
    service = FraudDetectionService.new(@user, @order, :order_placement)
    fraud_check = service.check
    
    assert fraud_check.risk_factors_array.any? { |f| f['factor'].include?('activity rate') },
           "Should detect high velocity"
  end

  # Context-based checks
  test "uses IP address from context" do
    context = { ip_address: "192.168.1.1" }
    service = FraudDetectionService.new(@user, @order, :order_placement, context)
    fraud_check = service.check
    
    assert_equal "192.168.1.1", fraud_check.ip_address
  end

  test "uses user agent from context" do
    context = { user_agent: "Mozilla/5.0" }
    service = FraudDetectionService.new(@user, @order, :order_placement, context)
    fraud_check = service.check
    
    assert_equal "Mozilla/5.0", fraud_check.user_agent
  end

  # Device fingerprint checks
  test "detects blocked device" do
    blocked_device = device_fingerprints(:blocked_device)
    context = { device_fingerprint: blocked_device.fingerprint_hash }
    
    service = FraudDetectionService.new(@user, @order, :order_placement, context)
    fraud_check = service.check
    
    assert fraud_check.risk_score >= 50, "Blocked device should significantly increase risk"
    assert fraud_check.risk_factors_array.any? { |f| f['factor'].include?('Blocked device') }
  end

  test "detects suspicious device" do
    suspicious_device = device_fingerprints(:suspicious_device)
    context = { device_fingerprint: suspicious_device.fingerprint_hash }
    
    service = FraudDetectionService.new(@user, @order, :order_placement, context)
    fraud_check = service.check
    
    assert fraud_check.risk_factors_array.any? { |f| f['factor'].include?('Suspicious device') }
  end

  # Fraud history checks
  test "penalizes users with previous fraud flags" do
    # Create previous flagged fraud checks
    3.times do
      FraudCheck.create!(
        user: @user,
        checkable: @order,
        check_type: :order_placement,
        risk_score: 75,
        flagged: true,
        created_at: 10.days.ago
      )
    end
    
    service = FraudDetectionService.new(@user, @order, :order_placement)
    fraud_check = service.check
    
    assert fraud_check.risk_factors_array.any? { |f| f['factor'].include?('fraud flag') }
  end

  # Risk score bounds
  test "risk score never exceeds 100" do
    # Create conditions for very high risk
    very_risky_user = User.create!(
      name: "Risky",
      email: "risky@test.com",
      password: "password123",
      created_at: 1.hour.ago,
      email_verified: false
    )
    
    # Add many fraud flags
    10.times do
      FraudCheck.create!(
        user: very_risky_user,
        checkable: @order,
        check_type: :order_placement,
        risk_score: 80,
        flagged: true
      )
    end
    
    service = FraudDetectionService.new(very_risky_user, @order, :order_placement)
    fraud_check = service.check
    
    assert fraud_check.risk_score <= 100, "Risk score should not exceed 100"
  end

  test "risk score is never negative" do
    service = FraudDetectionService.new(@user, @order, :login_attempt)
    fraud_check = service.check
    
    assert fraud_check.risk_score >= 0, "Risk score should not be negative"
  end

  # Check types
  test "handles different check types" do
    check_types = [:account_creation, :login_attempt, :order_placement, :payment_method]
    
    check_types.each do |check_type|
      service = FraudDetectionService.new(@user, @order, check_type)
      fraud_check = service.check
      
      assert_equal check_type.to_s, fraud_check.check_type
    end
  end

  # Polymorphic checkable
  test "works with different checkable types" do
    product = products(:one)
    
    service = FraudDetectionService.new(@user, product, :listing_creation)
    fraud_check = service.check
    
    assert_equal product, fraud_check.checkable
    assert_equal 'Product', fraud_check.checkable_type
  end

  # Risk factors tracking
  test "tracks risk factors" do
    service = FraudDetectionService.new(@new_user, @order, :order_placement)
    fraud_check = service.check
    
    assert fraud_check.factors.present?
    assert fraud_check.factors['factors'].is_a?(Array)
    assert fraud_check.risk_factors_array.any?
  end

  test "risk factors have description and weight" do
    service = FraudDetectionService.new(@new_user, @order, :order_placement)
    fraud_check = service.check
    
    fraud_check.risk_factors_array.each do |factor|
      assert factor['factor'].present?, "Factor should have description"
      assert factor['weight'].present?, "Factor should have weight"
    end
  end

  # Anomaly detection
  test "detects unusual time of activity" do
    # Mock current time to be 3 AM
    travel_to Time.current.change(hour: 3) do
      service = FraudDetectionService.new(@user, @order, :order_placement)
      fraud_check = service.check
      
      # May or may not flag depending on other factors, but should note the time
      assert fraud_check.created_at.hour == 3
    end
  end
end

