# =============================================================================
# Monitor Network Conditions Job - Adaptive Network Monitoring
# =============================================================================
# This job monitors XRP network conditions for adaptive fee calculation
# and performance optimization, integrating with ledger services for
# real-time network state awareness.

class MonitorNetworkConditionsJob < ApplicationJob
  queue_as :low_priority

  # Perform network condition monitoring
  # @param transaction_id [Integer] The transaction ID to monitor for
  def perform(transaction_id)
    transaction = XrpTransaction.find_by(id: transaction_id)
    return unless transaction

    Rails.logger.info("Monitoring network conditions for transaction #{transaction_id}")

    network_stats = fetch_network_stats

    # Update fee if conditions have changed significantly
    update_fee_if_needed(transaction, network_stats)

    # Reschedule for periodic monitoring
    self.class.perform_in(30.minutes, transaction_id)
  end

  private

  # Fetch current network statistics
  # @return [Hash] Network statistics
  def fetch_network_stats
    XrpLedgerService.get_network_fee_stats
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch network stats: #{e.message}")
    { recent_fees: [], network_load: 0.5 }
  end

  # Update transaction fee if network conditions warrant it
  # @param transaction [XrpTransaction] The transaction
  # @param stats [Hash] Network statistics
  def update_fee_if_needed(transaction, stats)
    current_multiplier = FeeCalculationService.calculate_congestion_multiplier(stats)

    # Only update if multiplier changed by more than 10%
    if (current_multiplier - 1.0).abs > 0.1
      new_fee_result = FeeCalculationService.calculate_fee(transaction)
      if new_fee_result.success?
        transaction.update!(fee_xrp: new_fee_result.value!)
        Rails.logger.info("Updated fee for transaction #{transaction.id} to #{new_fee_result.value!}")
      end
    end
  end
end