class CreateXrpWalletSystem < ActiveRecord::Migration[8.0]
  def change
    # =============================================================================
    # XRP Wallet Management - Zero-Trust Cryptographic Wallet Infrastructure
    # =============================================================================

    # XRP Wallets for secure XRP storage and transactions
    create_table :xrp_wallets, comment: 'XRP wallet management with homomorphic encryption' do |t|
      t.references :user, null: false, foreign_key: true, comment: 'Wallet owner'
      t.references :payment_account, foreign_key: true, comment: 'Associated payment account'

      # XRP wallet core data
      t.string :xrp_address, null: false, limit: 34, comment: 'XRP wallet address (starts with r)'
      t.string :secret_key_encrypted, limit: 512, comment: 'Encrypted wallet secret key'
      t.string :public_key, limit: 66, comment: 'Wallet public key for verification'

      # Balance and ledger tracking
      t.decimal :balance_xrp, precision: 20, scale: 6, default: 0.0, null: false, comment: 'Current XRP balance'
      t.integer :ledger_version, comment: 'Last synced ledger version'
      t.datetime :last_sync_at, comment: 'Last balance synchronization'
      t.integer :sequence_number, default: 0, comment: 'Next transaction sequence number'

      # Wallet configuration
      t.string :status, default: 'active', limit: 20, null: false, comment: 'Wallet operational status'
      t.string :wallet_type, default: 'standard', limit: 20, comment: 'Type of wallet (standard, multisig, escrow)'
      t.jsonb :configuration, default: {}, comment: 'Wallet-specific configuration'
      t.jsonb :metadata, default: {}, comment: 'Additional wallet metadata'

      # Security and compliance
      t.string :kyc_status, default: 'pending', limit: 20, comment: 'KYC verification status'
      t.string :risk_score, limit: 3, comment: 'Wallet risk assessment score (0-100)'
      t.datetime :last_risk_assessment_at, comment: 'Last risk assessment timestamp'

      # Monitoring and analytics
      t.integer :total_transactions, default: 0, comment: 'Total transactions processed'
      t.decimal :total_volume_xrp, precision: 20, scale: 6, default: 0.0, comment: 'Total XRP volume processed'
      t.datetime :created_at, null: false, comment: 'Wallet creation timestamp'
      t.datetime :updated_at, null: false, comment: 'Last update timestamp'

      # Performance indexes for wallet operations
      t.index :xrp_address, unique: true, comment: 'Unique XRP address lookup'
      t.index :user_id, comment: 'User wallet lookup'
      t.index :status, comment: 'Status-based filtering'
      t.index :kyc_status, comment: 'KYC status filtering'
      t.index [:balance_xrp, :status], comment: 'Balance and status queries'
      t.index :last_sync_at, comment: 'Sync status monitoring'
    end

    # XRP Transaction records with full audit trail
    create_table :xrp_transactions, comment: 'XRP transaction records with homomorphic verification' do |t|
      t.references :source_wallet, null: true, foreign_key: { to_table: :xrp_wallets }, comment: 'Source wallet for outgoing transactions'
      t.references :destination_wallet, null: true, foreign_key: { to_table: :xrp_wallets }, comment: 'Destination wallet for incoming transactions'
      t.references :order, foreign_key: true, comment: 'Associated order if applicable'
      t.references :user, null: false, foreign_key: true, comment: 'Transaction initiator'

      # Transaction identification
      t.string :transaction_hash, limit: 64, comment: 'XRP ledger transaction hash'
      t.string :destination_address, null: false, limit: 34, comment: 'XRP destination address'
      t.string :source_address, limit: 34, comment: 'XRP source address'

      # Transaction amounts and fees
      t.decimal :amount_xrp, precision: 20, scale: 6, null: false, comment: 'Transaction amount in XRP'
      t.decimal :fee_xrp, precision: 10, scale: 6, default: 0.0, comment: 'Transaction fee in XRP'
      t.decimal :amount_usd, precision: 15, scale: 2, comment: 'Transaction amount in USD'

      # Transaction metadata
      t.string :transaction_type, null: false, limit: 20, comment: 'Type of transaction'
      t.string :status, default: 'pending', limit: 20, null: false, comment: 'Transaction status'
      t.string :priority, default: 'normal', limit: 10, comment: 'Transaction priority level'

      # Ledger information
      t.integer :ledger_version, comment: 'Ledger version where transaction was included'
      t.integer :sequence, comment: 'Account sequence number'
      t.integer :confirmations, default: 0, comment: 'Number of confirmations received'
      t.datetime :confirmed_at, comment: 'Transaction confirmation timestamp'
      t.datetime :submitted_at, comment: 'Transaction submission timestamp'
      t.datetime :expires_at, comment: 'Transaction expiration time'

      # Error handling and retry logic
      t.string :error_message, limit: 500, comment: 'Last error message if failed'
      t.integer :retry_count, default: 0, comment: 'Number of retry attempts'
      t.datetime :last_retry_at, comment: 'Last retry attempt timestamp'
      t.integer :monitoring_failures, default: 0, comment: 'Monitoring failure count'

      # Advanced features
      t.string :destination_tag, limit: 10, comment: 'XRP destination tag for exchanges'
      t.jsonb :memos, default: [], comment: 'Transaction memos for additional data'
      t.jsonb :flags, default: {}, comment: 'XRP transaction flags'
      t.jsonb :metadata, default: {}, comment: 'Additional transaction metadata'

      # Compliance and risk
      t.string :compliance_status, default: 'pending', limit: 20, comment: 'Compliance review status'
      t.string :risk_flags, array: true, default: [], comment: 'Risk assessment flags'
      t.datetime :disputed_at, comment: 'Dispute initiation timestamp'
      t.string :dispute_reason, limit: 255, comment: 'Reason for dispute'

      # Performance tracking
      t.decimal :gas_price, precision: 15, scale: 6, comment: 'Network gas price at time of transaction'
      t.decimal :exchange_rate, precision: 15, scale: 6, comment: 'XRP/USD rate at transaction time'
      t.datetime :created_at, null: false, comment: 'Transaction creation timestamp'
      t.datetime :updated_at, null: false, comment: 'Last update timestamp'

      # Performance indexes for transaction operations
      t.index :transaction_hash, unique: true, comment: 'Unique transaction hash lookup'
      t.index :destination_address, comment: 'Destination address queries'
      t.index :source_address, comment: 'Source address queries'
      t.index [:status, :created_at], comment: 'Status and time-based queries'
      t.index [:user_id, :status], comment: 'User transaction history'
      t.index :transaction_type, comment: 'Transaction type filtering'
      t.index :confirmed_at, comment: 'Confirmation time queries'
      t.index :ledger_version, comment: 'Ledger version queries'
      t.index :expires_at, comment: 'Expiration monitoring'
      t.index :compliance_status, comment: 'Compliance review filtering'
    end

    # XRP Exchange Transactions for currency conversion tracking
    create_table :xrp_exchange_transactions, comment: 'XRP exchange transactions with revenue capture' do |t|
      t.references :source_wallet, null: false, foreign_key: { to_table: :xrp_wallets }, comment: 'Source XRP wallet'
      t.references :user, null: false, foreign_key: true, comment: 'User initiating exchange'

      # Exchange details
      t.string :target_currency, null: false, limit: 10, comment: 'Target currency for exchange'
      t.decimal :amount_xrp, precision: 20, scale: 6, null: false, comment: 'Amount of XRP to exchange'
      t.decimal :amount_target, precision: 20, scale: 6, comment: 'Amount received in target currency'
      t.decimal :exchange_rate, precision: 15, scale: 6, null: false, comment: 'Exchange rate applied'
      t.decimal :revenue_captured_usd, precision: 10, scale: 2, default: 1.0, comment: 'Revenue captured ($1 base)'

      # Exchange execution
      t.string :status, default: 'pending', limit: 20, null: false, comment: 'Exchange status'
      t.string :exchange_provider, limit: 20, comment: 'Exchange platform used'
      t.string :exchange_transaction_hash, limit: 64, comment: 'External exchange transaction ID'
      t.decimal :executed_rate, precision: 15, scale: 6, comment: 'Actual executed exchange rate'
      t.datetime :executed_at, comment: 'Exchange execution timestamp'
      t.datetime :expires_at, comment: 'Exchange expiration time'

      # Error handling
      t.string :error_message, limit: 500, comment: 'Exchange error details'
      t.integer :retry_count, default: 0, comment: 'Exchange retry attempts'
      t.datetime :failed_at, comment: 'Exchange failure timestamp'

      # Additional metadata
      t.jsonb :exchange_metadata, default: {}, comment: 'Exchange-specific data'
      t.jsonb :options, default: {}, comment: 'Exchange options and preferences'

      # Performance tracking
      t.decimal :slippage_percent, precision: 5, scale: 2, comment: 'Price slippage percentage'
      t.decimal :fee_amount, precision: 10, scale: 6, comment: 'Exchange fee amount'
      t.datetime :created_at, null: false, comment: 'Exchange creation timestamp'
      t.datetime :updated_at, null: false, comment: 'Last update timestamp'

      # Performance indexes for exchange operations
      t.index [:status, :created_at], comment: 'Status and time-based queries'
      t.index [:user_id, :status], comment: 'User exchange history'
      t.index :target_currency, comment: 'Currency-based filtering'
      t.index :expires_at, comment: 'Expiration monitoring'
      t.index :exchange_provider, comment: 'Exchange provider filtering'
    end

    # XRP Exchange Locks for preventing double-spending
    create_table :xrp_exchange_locks, comment: 'XRP exchange locks for double-spend prevention' do |t|
      t.references :xrp_wallet, null: false, foreign_key: true, comment: 'Wallet being locked'
      t.decimal :amount_xrp, precision: 20, scale: 6, null: false, comment: 'Locked amount'
      t.string :lock_type, default: 'exchange', limit: 20, comment: 'Type of lock'
      t.string :lock_purpose, limit: 255, comment: 'Purpose of the lock'
      t.datetime :expires_at, null: false, comment: 'Lock expiration time'
      t.datetime :released_at, comment: 'Lock release timestamp'
      t.timestamps

      t.index [:xrp_wallet_id, :expires_at], comment: 'Active locks by wallet'
      t.index :expires_at, comment: 'Expired lock cleanup'
      t.index :lock_type, comment: 'Lock type filtering'
    end

    # XRP Wallet Sync Failures for monitoring
    create_table :xrp_wallet_sync_failures, comment: 'XRP wallet synchronization failure tracking' do |t|
      t.references :xrp_wallet, null: false, foreign_key: true, comment: 'Wallet with sync failure'
      t.string :error_type, null: false, limit: 100, comment: 'Type of error encountered'
      t.text :error_message, comment: 'Detailed error message'
      t.string :operation, limit: 50, comment: 'Operation that failed'
      t.jsonb :context, default: {}, comment: 'Additional error context'
      t.datetime :occurred_at, null: false, comment: 'When the failure occurred'
      t.datetime :resolved_at, comment: 'When the failure was resolved'

      t.index [:xrp_wallet_id, :occurred_at], comment: 'Wallet failure history'
      t.index :error_type, comment: 'Error type analysis'
      t.index :occurred_at, comment: 'Failure timeline'
    end

    # Daily XRP Exchange Statistics for business intelligence
    create_table :daily_xrp_exchange_stats, comment: 'Daily XRP exchange statistics and revenue tracking' do |t|
      t.date :date, null: false, comment: 'Statistics date'
      t.decimal :total_revenue_usd, precision: 15, scale: 2, default: 0.0, comment: 'Total revenue captured'
      t.integer :total_trades, default: 0, comment: 'Total exchange transactions'
      t.decimal :total_volume_xrp, precision: 20, scale: 6, default: 0.0, comment: 'Total XRP volume exchanged'
      t.decimal :average_trade_size_xrp, precision: 15, scale: 6, comment: 'Average trade size in XRP'
      t.decimal :average_revenue_per_trade, precision: 10, scale: 2, comment: 'Average revenue per trade'
      t.jsonb :exchange_distribution, default: {}, comment: 'Usage distribution by exchange'
      t.jsonb :currency_distribution, default: {}, comment: 'Exchange distribution by target currency'
      t.timestamps

      t.index :date, unique: true, comment: 'Unique date lookup'
      t.index :total_revenue_usd, comment: 'Revenue-based sorting'
    end

    # XRP Revenue Capture tracking for financial reporting
    create_table :xrp_revenue_captures, comment: 'XRP exchange revenue capture tracking' do |t|
      t.decimal :amount_usd, precision: 10, scale: 2, null: false, comment: 'Revenue amount captured'
      t.string :source, null: false, limit: 20, comment: 'Revenue source (exchange, fee, etc.)'
      t.references :xrp_exchange_transaction, foreign_key: true, comment: 'Associated exchange transaction'
      t.references :user, foreign_key: true, comment: 'User who generated revenue'
      t.string :revenue_type, limit: 20, comment: 'Type of revenue (base, volume_bonus, etc.)'
      t.decimal :exchange_rate, precision: 15, scale: 6, comment: 'XRP/USD rate at capture time'
      t.datetime :captured_at, null: false, comment: 'When revenue was captured'
      t.jsonb :metadata, default: {}, comment: 'Additional revenue metadata'

      t.index [:source, :captured_at], comment: 'Source and time-based queries'
      t.index :amount_usd, comment: 'Amount-based filtering'
      t.index :captured_at, comment: 'Time-based reporting'
    end

    # XRP Exchange Failures for analytics and debugging
    create_table :xrp_exchange_failures, comment: 'XRP exchange failure tracking and analysis' do |t|
      t.references :xrp_exchange_transaction, foreign_key: true, comment: 'Failed exchange transaction'
      t.string :error_type, null: false, limit: 100, comment: 'Type of error encountered'
      t.text :error_message, comment: 'Detailed error message'
      t.string :exchange_provider, limit: 20, comment: 'Exchange that failed'
      t.string :failure_stage, limit: 20, comment: 'Stage where failure occurred'
      t.decimal :amount_xrp, precision: 20, scale: 6, comment: 'Amount being exchanged'
      t.string :target_currency, limit: 10, comment: 'Target currency'
      t.datetime :occurred_at, null: false, comment: 'When the failure occurred'
      t.integer :retry_attempt, default: 0, comment: 'Retry attempt number'
      t.jsonb :context, default: {}, comment: 'Additional failure context'

      t.index [:exchange_provider, :occurred_at], comment: 'Exchange failure patterns'
      t.index :error_type, comment: 'Error type analysis'
      t.index :occurred_at, comment: 'Failure timeline'
    end

    # Add constraints for data integrity
    add_constraints
  end

  private

  def add_constraints
    # XRP address format validation (starts with 'r', 34 characters)
    execute <<-SQL
      ALTER TABLE xrp_wallets ADD CONSTRAINT valid_xrp_address
      CHECK (xrp_address ~ '^r[rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz]{27,35}$')
    SQL

    # XRP amount must be positive
    execute <<-SQL
      ALTER TABLE xrp_transactions ADD CONSTRAINT positive_xrp_amount
      CHECK (amount_xrp > 0)
    SQL

    # Fee must be non-negative
    execute <<-SQL
      ALTER TABLE xrp_transactions ADD CONSTRAINT non_negative_fee
      CHECK (fee_xrp >= 0)
    SQL

    # Wallet balance must be non-negative
    execute <<-SQL
      ALTER TABLE xrp_wallets ADD CONSTRAINT non_negative_balance
      CHECK (balance_xrp >= 0)
    SQL

    # Status values must be valid
    execute <<-SQL
      ALTER TABLE xrp_wallets ADD CONSTRAINT valid_wallet_status
      CHECK (status IN ('active', 'suspended', 'locked', 'closed', 'pending_verification'))
    SQL

    execute <<-SQL
      ALTER TABLE xrp_transactions ADD CONSTRAINT valid_transaction_status
      CHECK (status IN ('pending', 'submitted', 'pending_confirmation', 'confirmed', 'failed', 'cancelled', 'expired', 'disputed', 'quarantined'))
    SQL

    # Transaction hash format validation
    execute <<-SQL
      ALTER TABLE xrp_transactions ADD CONSTRAINT valid_transaction_hash
      CHECK (transaction_hash ~ '^[A-Fa-f0-9]{64}$' OR transaction_hash IS NULL)
    SQL
  end
end