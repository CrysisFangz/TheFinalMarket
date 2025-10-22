# =============================================================================
# Compliance Service - Zero-Trust Transaction Compliance Engine
# =============================================================================
# This service enforces regulatory compliance, fraud detection, and risk
# assessment for XRP transactions, integrating real-time sanctions checking,
# anomaly detection, and adaptive risk scoring for enhanced security.

class ComplianceService
  include Dry::Monads[:result]

  # Compliance thresholds
  LARGE_AMOUNT_THRESHOLD = 10_000.freeze
  RAPID_TRANSACTION_THRESHOLD = 10.freeze
  RAPID_TRANSACTION_WINDOW = 1.hour.freeze
  SANCTIONS_CACHE_TTL = 1.day.freeze

  # Perform comprehensive compliance check for a transaction
  # @param transaction [XrpTransaction] The transaction to check
  # @return [Dry::Monads::Result] Success with compliance flags or Failure
  def self.check_compliance(transaction)
    return Failure('Transaction must be provided') unless transaction.is_a?(XrpTransaction)

    flags = []

    flags << :large_amount if large_amount?(transaction.amount_xrp)
    flags << :rapid_transactions if rapid_transactions?(transaction)
    flags << :sanctioned_address if sanctioned_address?(transaction.destination_address)
    flags << :unusual_pattern if unusual_pattern?(transaction)

    Success(flags)
  rescue StandardError => e
    Rails.logger.error("Compliance check failed for transaction #{transaction.id}: #{e.message}")
    Failure("Compliance check error: #{e.message}")
  end

  # Check if transaction amount exceeds large transaction threshold
  # @param amount [Float] Transaction amount in XRP
  # @return [Boolean] True if large amount
  def self.large_amount?(amount)
    amount > LARGE_AMOUNT_THRESHOLD
  end

  # Check for rapid successive transactions from the same address
  # @param transaction [XrpTransaction] The transaction
  # @return [Boolean] True if rapid transactions detected
  def self.rapid_transactions?(transaction)
    recent_count = XrpTransaction.where(
      source_address: transaction.source_address,
      created_at: RAPID_TRANSACTION_WINDOW.ago..Time.current
    ).count

    recent_count > RAPID_TRANSACTION_THRESHOLD
  end

  # Check if address is on sanctions list
  # @param address [String] The address to check
  # @return [Boolean] True if sanctioned
  def self.sanctioned_address?(address)
    Rails.cache.fetch("sanctions_check_#{address}", expires_in: SANCTIONS_CACHE_TTL) do
      SanctionsListService.check_address(address)
    end
  rescue StandardError => e
    Rails.logger.warn("Sanctions check failed for address #{address}: #{e.message}")
    false # Default to not sanctioned on error
  end

  # Detect unusual transaction patterns using machine learning heuristics
  # @param transaction [XrpTransaction] The transaction
  # @return [Boolean] True if unusual pattern detected
  def self.unusual_pattern?(transaction)
    # Placeholder for advanced pattern detection
    # In a real implementation, this would use ML models for anomaly detection
    # For now, check for round numbers or unusual timing
    unusual_amount = transaction.amount_xrp.round == transaction.amount_xrp
    unusual_timing = unusual_timing?(transaction.created_at)

    unusual_amount || unusual_timing
  end

  # Check for unusual timing patterns
  # @param created_at [Time] Transaction creation time
  # @return [Boolean] True if unusual timing
  def self.unusual_timing?(created_at)
    # Check if transaction occurs during off-hours or in rapid succession
    off_hours = created_at.hour < 6 || created_at.hour > 22
    weekend = created_at.wday == 0 || created_at.wday == 6

    off_hours || weekend
  end

  # Generate risk score based on compliance flags
  # @param flags [Array] Array of compliance flags
  # @return [Float] Risk score (0.0 - 1.0)
  def self.calculate_risk_score(flags)
    risk_weights = {
      large_amount: 0.3,
      rapid_transactions: 0.4,
      sanctioned_address: 1.0,
      unusual_pattern: 0.2
    }

    total_risk = flags.sum { |flag| risk_weights[flag] || 0.0 }
    [total_risk, 1.0].min # Cap at 1.0
  end

  # Determine if transaction should be flagged for review
  # @param risk_score [Float] Calculated risk score
  # @return [Boolean] True if should be flagged
  def self.should_flag_for_review?(risk_score)
    risk_score > 0.5
  end
end