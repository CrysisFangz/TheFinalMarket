# =============================================================================
# Fee Calculation Service - Adaptive Fee Optimization Engine
# =============================================================================
# This service implements sophisticated, real-time fee calculation for XRP
# transactions, incorporating network congestion analysis, priority-based
# multipliers, and historical trend forecasting for optimal cost efficiency.

class FeeCalculationService
  include Dry::Monads[:result]

  # Configuration constants for fee calculation
  BASE_FEE = XrpWallet::XRP_CONFIG[:transaction_fee].freeze
  CONGESTION_THRESHOLD = 0.7.freeze
  TREND_WEIGHT = 0.3.freeze

  # Calculate optimal transaction fee with adaptive multipliers
  # @param transaction [XrpTransaction] The transaction to calculate fee for
  # @return [Dry::Monads::Result] Success with calculated fee or Failure with error
  def self.calculate_fee(transaction)
    return Failure('Transaction must be provided') unless transaction.is_a?(XrpTransaction)

    network_stats = fetch_network_fee_stats
    congestion_multiplier = calculate_congestion_multiplier(network_stats)
    priority_multiplier = calculate_priority_multiplier(transaction.priority_level)

    calculated_fee = (BASE_FEE * congestion_multiplier * priority_multiplier).round(6)

    Success(calculated_fee)
  rescue StandardError => e
    Rails.logger.error("Fee calculation failed: #{e.message}")
    Failure("Fee calculation error: #{e.message}")
  end

  # Calculate network congestion multiplier based on real-time data
  # @param fee_stats [Hash] Network fee statistics
  # @return [Float] Congestion multiplier (1.0 - 2.0)
  def self.calculate_congestion_multiplier(fee_stats)
    recent_fees = fee_stats[:recent_fees] || []
    current_load = fee_stats[:network_load] || 0.5

    # Base multiplier from current load
    base_multiplier = 1.0 + (current_load * 0.5)

    # Incorporate trend analysis for predictive scaling
    if recent_fees.any?
      avg_recent_fee = recent_fees.sum / recent_fees.size.to_f
      trend_multiplier = (avg_recent_fee / BASE_FEE) * TREND_WEIGHT + (1 - TREND_WEIGHT)
      base_multiplier *= trend_multiplier
    end

    # Apply exponential backoff for high congestion
    base_multiplier *= Math.exp(current_load - CONGESTION_THRESHOLD) if current_load > CONGESTION_THRESHOLD

    [base_multiplier, 2.0].min # Cap at 2x to prevent excessive fees
  end

  # Calculate priority-based fee multiplier
  # @param priority_level [Symbol] Priority level (:low, :normal, :high, :urgent)
  # @return [Float] Priority multiplier
  def self.calculate_priority_multiplier(priority_level)
    case priority_level.to_sym
    when :low
      1.0
    when :normal
      1.2
    when :high
      1.5
    when :urgent
      2.0
    else
      1.0
    end
  end

  private

  # Fetch current network fee statistics from ledger service
  # @return [Hash] Network statistics
  def self.fetch_network_fee_stats
    XrpLedgerService.get_network_fee_stats
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch network stats: #{e.message}")
    { recent_fees: [], network_load: 0.5 } # Default fallback
  end
end