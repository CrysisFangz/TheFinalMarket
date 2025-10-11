class CreateBlockchainWeb3System < ActiveRecord::Migration[8.0]
  def change
    # NFTs
    create_table :nfts do |t|
      t.references :product, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :token_id, null: false
      t.string :contract_address, null: false
      t.string :name, null: false
      t.text :description
      t.integer :nft_type, null: false, default: 0
      t.integer :blockchain, default: 1
      t.boolean :for_sale, default: false
      t.integer :sale_price_cents
      t.integer :last_sale_price_cents
      t.integer :royalty_percentage, default: 10
      t.integer :transfer_count, default: 0
      t.string :ipfs_hash
      t.string :transaction_hash
      t.integer :blockchain_status, default: 0
      t.datetime :minted_at
      t.datetime :listed_at
      t.jsonb :metadata, default: {}
      
      t.timestamps
      
      t.index :token_id, unique: true
      t.index :contract_address
      t.index :nft_type
      t.index :creator_id
      t.index :owner_id
      t.index :for_sale
    end
    
    # NFT Transfers
    create_table :nft_transfers do |t|
      t.references :nft, null: false, foreign_key: true
      t.references :from_user, null: false, foreign_key: { to_table: :users }
      t.references :to_user, null: false, foreign_key: { to_table: :users }
      t.integer :price_cents, default: 0
      t.string :transaction_hash
      t.datetime :transferred_at
      
      t.timestamps
      
      t.index :transaction_hash
      t.index :transferred_at
    end
    
    # NFT Bids
    create_table :nft_bids do |t|
      t.references :nft, null: false, foreign_key: true
      t.references :bidder, null: false, foreign_key: { to_table: :users }
      t.integer :amount_cents, null: false
      t.integer :status, default: 0
      t.datetime :expires_at
      
      t.timestamps
      
      t.index :status
      t.index :expires_at
    end
    
    # Crypto Payments
    create_table :crypto_payments do |t|
      t.references :order, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :cryptocurrency, null: false
      t.decimal :amount_crypto, precision: 18, scale: 8, null: false
      t.integer :amount_usd_cents, null: false
      t.decimal :exchange_rate, precision: 18, scale: 8
      t.string :wallet_address, null: false
      t.string :transaction_hash
      t.integer :confirmations, default: 0
      t.integer :status, default: 0
      t.datetime :expires_at
      t.datetime :confirmed_at
      t.decimal :actual_amount_received, precision: 18, scale: 8
      t.boolean :refunded, default: false
      t.string :refund_transaction_hash
      t.datetime :refunded_at
      
      t.timestamps
      
      t.index :cryptocurrency
      t.index :status
      t.index :transaction_hash
      t.index :wallet_address
    end
    
    # Crypto Exchange Rates
    create_table :crypto_exchange_rates do |t|
      t.integer :cryptocurrency, null: false
      t.string :fiat_currency, default: 'USD'
      t.decimal :rate, precision: 18, scale: 8, null: false
      t.datetime :fetched_at
      
      t.timestamps
      
      t.index [:cryptocurrency, :fiat_currency]
      t.index :fetched_at
    end
    
    # Blockchain Provenance
    create_table :blockchain_provenances do |t|
      t.references :product, null: false, foreign_key: true
      t.string :blockchain_id, null: false
      t.integer :blockchain, default: 1
      t.boolean :verified, default: false
      t.datetime :verified_at
      t.string :verification_hash
      t.integer :blockchain_status, default: 0
      t.jsonb :origin_data, default: {}
      
      t.timestamps
      
      t.index :blockchain_id, unique: true
      t.index :verified
    end
    
    # Provenance Events
    create_table :provenance_events do |t|
      t.references :blockchain_provenance, null: false, foreign_key: true
      t.integer :event_type, null: false
      t.text :description
      t.string :blockchain_hash
      t.datetime :occurred_at
      t.jsonb :event_data, default: {}
      
      t.timestamps
      
      t.index :event_type
      t.index :occurred_at
    end
    
    # Loyalty Tokens
    create_table :loyalty_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :balance, default: 0
      t.integer :staked_balance, default: 0
      t.integer :total_earned, default: 0
      t.integer :total_spent, default: 0
      t.string :exported_to_wallet
      
      t.timestamps
      
      t.index :balance
    end
    
    # Token Transactions
    create_table :token_transactions do |t|
      t.references :loyalty_token, null: false, foreign_key: true
      t.integer :transaction_type, null: false
      t.integer :amount, null: false
      t.integer :balance_after, null: false
      t.string :reason
      t.jsonb :metadata, default: {}
      
      t.timestamps
      
      t.index :transaction_type
      t.index :created_at
    end
    
    # Token Rewards
    create_table :token_rewards do |t|
      t.references :loyalty_token, null: false, foreign_key: true
      t.integer :reward_type, null: false
      t.integer :amount_staked
      t.integer :reward_amount
      t.decimal :apy, precision: 5, scale: 2
      t.integer :status, default: 0
      t.datetime :starts_at
      t.datetime :ends_at
      t.datetime :claimed_at
      
      t.timestamps
      
      t.index :reward_type
      t.index :status
      t.index :ends_at
    end
    
    # Smart Contracts
    create_table :smart_contracts do |t|
      t.references :order, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.integer :contract_type, null: false
      t.integer :status, default: 0
      t.string :contract_address
      t.string :deployment_hash
      t.datetime :deployed_at
      t.datetime :activated_at
      t.jsonb :contract_params, default: {}
      
      t.timestamps
      
      t.index :contract_type
      t.index :status
      t.index :contract_address
    end
    
    # Contract Executions
    create_table :contract_executions do |t|
      t.references :smart_contract, null: false, foreign_key: true
      t.string :function_name, null: false
      t.jsonb :parameters, default: {}
      t.integer :status, default: 0
      t.string :transaction_hash
      t.integer :gas_used
      t.jsonb :result, default: {}
      t.datetime :executed_at
      
      t.timestamps
      
      t.index :function_name
      t.index :status
      t.index :transaction_hash
    end
    
    # Decentralized Reviews
    create_table :decentralized_reviews do |t|
      t.references :product, null: false, foreign_key: true
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.integer :rating, null: false
      t.text :content, null: false
      t.string :content_hash, null: false
      t.string :blockchain_hash, null: false
      t.string :ipfs_hash
      t.integer :blockchain_status, default: 0
      t.boolean :verified, default: false
      t.datetime :verified_at
      t.datetime :written_at
      t.integer :helpful_count, default: 0
      t.integer :not_helpful_count, default: 0
      t.integer :verification_count, default: 0
      t.jsonb :metadata, default: {}
      
      t.timestamps
      
      t.index :blockchain_hash, unique: true
      t.index :ipfs_hash
      t.index :verified
      t.index :rating
    end
    
    # Review Verifications
    create_table :review_verifications do |t|
      t.references :decentralized_review, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :helpful, null: false
      t.datetime :verified_at
      
      t.timestamps
      
      t.index [:decentralized_review_id, :user_id], unique: true, name: 'index_review_verifications_on_review_and_user'
    end
    
    # Royalty Payments
    create_table :royalty_payments do |t|
      t.references :nft, null: false, foreign_key: true
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.integer :amount_cents, null: false
      t.integer :sale_price_cents, null: false
      t.string :transaction_hash
      t.datetime :paid_at
      
      t.timestamps
      
      t.index :transaction_hash
      t.index :paid_at
    end
    
    # Add wallet address to users
    add_column :users, :wallet_address, :string
    add_column :users, :wallet_connected, :boolean, default: false
    add_column :users, :wallet_type, :string
    
    add_index :users, :wallet_address, unique: true
  end
end

