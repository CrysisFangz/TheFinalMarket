# MultiCurrencyWalletPortfolioSnapshotJob
# Async job for creating portfolio snapshots
class MultiCurrencyWalletPortfolioSnapshotJob < ApplicationJob
  queue_as :default

  def perform(wallet_id, snapshot_type = :regular)
    wallet = MultiCurrencyWallet.find(wallet_id)
    wallet.create_portfolio_snapshot!(snapshot_type)
  end
end