puts "⛓️  Seeding Blockchain & Web3 System..."

# Add wallet addresses to users
puts "Adding wallet addresses to users..."

User.limit(20).each do |user|
  user.update!(
    wallet_address: "0x#{SecureRandom.hex(20)}",
    wallet_connected: [true, false].sample,
    wallet_type: ['MetaMask', 'WalletConnect', 'Coinbase Wallet'].sample
  )
end

puts "✅ Added wallet addresses to #{User.where.not(wallet_address: nil).count} users"

# Create loyalty tokens
puts "Creating loyalty tokens..."

User.limit(30).each do |user|
  LoyaltyToken.create!(
    user: user,
    balance: rand(100..5000),
    total_earned: rand(500..10000),
    total_spent: rand(0..5000)
  )
end

puts "✅ Created #{LoyaltyToken.count} loyalty token accounts"

# Create NFTs
puts "Creating NFTs..."

creators = User.where.not(wallet_address: nil).limit(10)

30.times do
  creator = creators.sample
  owner = User.where.not(wallet_address: nil).sample
  
  Nft.create!(
    creator: creator,
    owner: owner,
    name: Faker::Commerce.product_name,
    description: Faker::Lorem.paragraph,
    nft_type: [:digital_art, :collectible, :limited_edition_product, :membership_pass].sample,
    token_id: SecureRandom.hex(32),
    contract_address: "0x#{SecureRandom.hex(20)}",
    blockchain: :polygon,
    for_sale: [true, false].sample,
    sale_price_cents: rand(1000..100000),
    royalty_percentage: [5, 10, 15].sample,
    minted_at: rand(1..90).days.ago,
    metadata: {
      traits: [
        { name: 'Rarity', value: ['Common', 'Rare', 'Epic', 'Legendary'].sample },
        { name: 'Edition', value: "#{rand(1..100)}/100" }
      ]
    }
  )
end

puts "✅ Created #{Nft.count} NFTs"

# Create blockchain provenance records
puts "Creating blockchain provenance records..."

Product.limit(20).each do |product|
  provenance = BlockchainProvenance.create_for_product(
    product,
    {
      manufacturer: Faker::Company.name,
      origin_country: Faker::Address.country,
      manufacture_date: rand(30..180).days.ago.to_date
    }
  )
  
  # Add some events
  provenance.track_manufacturing(
    Faker::Company.name,
    Faker::Address.city,
    "BATCH-#{rand(1000..9999)}"
  )
  
  provenance.track_quality_check(
    Faker::Name.name,
    true,
    'All quality checks passed'
  )
  
  provenance.track_certification(
    'ISO 9001',
    'International Standards Organization',
    "CERT-#{rand(10000..99999)}"
  )
  
  provenance.verify!
end

puts "✅ Created #{BlockchainProvenance.count} provenance records with #{ProvenanceEvent.count} events"

# Create crypto payments
puts "Creating crypto payments..."

Order.where(status: 'completed').limit(15).each do |order|
  CryptoPayment.create!(
    order: order,
    user: order.user,
    cryptocurrency: [:bitcoin, :ethereum, :usdc, :usdt].sample,
    amount_crypto: (order.total_cents / 100.0 / rand(20000..50000)).round(8),
    amount_usd_cents: order.total_cents,
    exchange_rate: rand(20000..50000),
    wallet_address: "0x#{SecureRandom.hex(20)}",
    transaction_hash: "0x#{SecureRandom.hex(32)}",
    confirmations: rand(6..50),
    status: :confirmed,
    confirmed_at: order.created_at + rand(5..30).minutes
  )
end

puts "✅ Created #{CryptoPayment.count} crypto payments"

# Create smart contracts
puts "Creating smart contracts..."

Order.limit(10).each do |order|
  contract = SmartContract.create!(
    order: order,
    creator: order.user,
    contract_type: :escrow,
    status: :active,
    contract_address: "0x#{SecureRandom.hex(20)}",
    deployment_hash: "0x#{SecureRandom.hex(32)}",
    deployed_at: order.created_at,
    activated_at: order.created_at + 5.minutes,
    contract_params: {
      buyer: order.user.wallet_address,
      seller: order.product&.seller&.wallet_address,
      amount: order.total_cents
    }
  )
  
  # Add some executions
  contract.contract_executions.create!(
    function_name: 'deposit',
    parameters: { amount: order.total_cents },
    status: :completed,
    transaction_hash: "0x#{SecureRandom.hex(32)}",
    gas_used: rand(21000..100000),
    executed_at: contract.activated_at
  )
end

puts "✅ Created #{SmartContract.count} smart contracts with #{ContractExecution.count} executions"

# Create decentralized reviews
puts "Creating decentralized reviews..."

Product.limit(15).each do |product|
  rand(2..5).times do
    reviewer = User.sample
    
    DecentralizedReview.create_review(
      product: product,
      reviewer: reviewer,
      rating: rand(3..5),
      content: Faker::Lorem.paragraph(sentence_count: 5),
      metadata: {
        verified_purchase: [true, false].sample,
        photos_count: rand(0..3)
      }
    )
  end
end

puts "✅ Created #{DecentralizedReview.count} decentralized reviews"

# Create token transactions
puts "Creating token transactions..."

LoyaltyToken.find_each do |token|
  # Earning transactions
  rand(5..15).times do
    token.token_transactions.create!(
      transaction_type: :earned,
      amount: rand(10..100),
      balance_after: token.balance,
      reason: ['Purchase reward', 'Review reward', 'Referral bonus', 'Daily login'].sample,
      created_at: rand(1..60).days.ago
    )
  end
  
  # Spending transactions
  rand(2..8).times do
    token.token_transactions.create!(
      transaction_type: :spent,
      amount: rand(10..50),
      balance_after: token.balance,
      reason: ['Discount redemption', 'Premium feature', 'Gift to friend'].sample,
      created_at: rand(1..30).days.ago
    )
  end
end

puts "✅ Created #{TokenTransaction.count} token transactions"

# Create staking rewards
puts "Creating staking rewards..."

LoyaltyToken.limit(10).each do |token|
  token.token_rewards.create!(
    reward_type: :staking,
    amount_staked: rand(100..1000),
    reward_amount: rand(10..100),
    apy: [5.0, 10.0, 15.0, 20.0].sample,
    status: [:active, :completed].sample,
    starts_at: rand(1..30).days.ago,
    ends_at: rand(30..90).days.from_now
  )
end

puts "✅ Created #{TokenReward.count} staking rewards"

puts "🎉 Blockchain & Web3 System seeded successfully!"
puts ""
puts "Summary:"
puts "  - #{User.where.not(wallet_address: nil).count} users with wallets"
puts "  - #{Nft.count} NFTs minted"
puts "  - #{BlockchainProvenance.count} provenance records"
puts "  - #{ProvenanceEvent.count} provenance events"
puts "  - #{CryptoPayment.count} crypto payments"
puts "  - #{SmartContract.count} smart contracts"
puts "  - #{DecentralizedReview.count} decentralized reviews"
puts "  - #{LoyaltyToken.count} loyalty token accounts"
puts "  - #{TokenTransaction.count} token transactions"
puts ""
puts "Web3 Features:"
puts "  ✅ NFT Marketplace (Digital Art, Collectibles, Limited Editions)"
puts "  ✅ Crypto Payments (BTC, ETH, USDC, USDT, DAI, MATIC, BNB)"
puts "  ✅ Blockchain Provenance (Product authenticity tracking)"
puts "  ✅ Loyalty Tokens (FMT - Final Market Token)"
puts "  ✅ Smart Contracts (Escrow, Marketplace, Auctions)"
puts "  ✅ Decentralized Reviews (IPFS + Blockchain verified)"
puts "  ✅ Token Staking (5-25% APY based on duration)"

