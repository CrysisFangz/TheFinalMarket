# =============================================================================
# Fee Calculation Service Test - Comprehensive Unit Tests
# =============================================================================
# This test suite validates the FeeCalculationService for correctness,
# edge cases, and performance under various network conditions.

require 'test_helper'

class FeeCalculationServiceTest < ActiveSupport::TestCase
  setup do
    @transaction = xrp_transactions(:one)
    @base_fee = XrpWallet::XRP_CONFIG[:transaction_fee]
  end

  test 'calculates fee successfully for valid transaction' do
    result = FeeCalculationService.calculate_fee(@transaction)

    assert result.success?
    assert_kind_of Numeric, result.value!
    assert result.value! > 0
  end

  test 'fails for invalid transaction' do
    result = FeeCalculationService.calculate_fee(nil)

    assert result.failure?
    assert_equal 'Transaction must be provided', result.failure
  end

  test 'calculates congestion multiplier correctly' do
    fee_stats = {
      recent_fees: [0.0001, 0.0002, 0.00015],
      network_load: 0.6
    }

    multiplier = FeeCalculationService.calculate_congestion_multiplier(fee_stats)

    assert_kind_of Numeric, multiplier
    assert multiplier >= 1.0
    assert multiplier <= 2.0
  end

  test 'calculates priority multiplier correctly' do
    assert_equal 1.0, FeeCalculationService.calculate_priority_multiplier(:low)
    assert_equal 1.2, FeeCalculationService.calculate_priority_multiplier(:normal)
    assert_equal 1.5, FeeCalculationService.calculate_priority_multiplier(:high)
    assert_equal 2.0, FeeCalculationService.calculate_priority_multiplier(:urgent)
    assert_equal 1.0, FeeCalculationService.calculate_priority_multiplier(:invalid)
  end

  test 'handles network stats fetch failure gracefully' do
    # Mock XrpLedgerService to raise error
    XrpLedgerService.stub :get_network_fee_stats, -> { raise StandardError.new('Network error') } do
      fee_stats = FeeCalculationService.send(:fetch_network_fee_stats)

      assert_equal [], fee_stats[:recent_fees]
      assert_equal 0.5, fee_stats[:network_load]
    end
  end

  test 'caps congestion multiplier at 2.0' do
    fee_stats = {
      recent_fees: [0.001, 0.002, 0.0015],
      network_load: 1.0
    }

    multiplier = FeeCalculationService.calculate_congestion_multiplier(fee_stats)

    assert multiplier <= 2.0
  end
end