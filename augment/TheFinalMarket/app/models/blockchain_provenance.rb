class BlockchainProvenance < ApplicationRecord
  belongs_to :product
  
  has_many :provenance_events, dependent: :destroy
  
  validates :product, presence: true
  validates :blockchain_id, presence: true, uniqueness: true
  
  scope :verified, -> { where(verified: true) }
  scope :by_blockchain, ->(chain) { where(blockchain: chain) }
  
  # Blockchain networks
  enum blockchain: {
    ethereum: 0,
    polygon: 1,
    hyperledger: 2,
    vechain: 3
  }
  
  # Create provenance record
  def self.create_for_product(product, origin_data = {})
    blockchain_id = generate_blockchain_id
    
    provenance = create!(
      product: product,
      blockchain_id: blockchain_id,
      blockchain: :polygon,
      origin_data: origin_data,
      verified: false
    )
    
    # Record creation event
    provenance.record_event(
      :created,
      'Product registered on blockchain',
      origin_data
    )
    
    # Write to blockchain
    provenance.write_to_blockchain
    
    provenance
  end
  
  # Record provenance event
  def record_event(event_type, description, data = {})
    event = provenance_events.create!(
      event_type: event_type,
      description: description,
      event_data: data,
      occurred_at: Time.current,
      blockchain_hash: generate_event_hash
    )
    
    # Write event to blockchain
    write_event_to_blockchain(event)
    
    event
  end
  
  # Verify provenance
  def verify!
    # Verify on blockchain
    blockchain_data = fetch_from_blockchain
    
    if blockchain_data[:verified]
      update!(
        verified: true,
        verified_at: Time.current,
        verification_hash: blockchain_data[:hash]
      )
    end
  end
  
  # Get provenance chain
  def provenance_chain
    provenance_events.order(occurred_at: :asc).map do |event|
      {
        type: event.event_type,
        description: event.description,
        timestamp: event.occurred_at,
        hash: event.blockchain_hash,
        data: event.event_data
      }
    end
  end
  
  # Get certificate
  def certificate
    {
      product_name: product.name,
      blockchain_id: blockchain_id,
      blockchain: blockchain,
      verified: verified?,
      created_at: created_at,
      origin: origin_data,
      events_count: provenance_events.count,
      verification_url: verification_url
    }
  end
  
  # Get verification URL
  def verification_url
    "#{ENV['APP_URL']}/provenance/verify/#{blockchain_id}"
  end
  
  # Get blockchain explorer URL
  def blockchain_explorer_url
    return nil unless verification_hash
    
    base_urls = {
      ethereum: 'https://etherscan.io/tx',
      polygon: 'https://polygonscan.com/tx',
      hyperledger: 'https://explorer.hyperledger.org/tx',
      vechain: 'https://explore.vechain.org/transactions'
    }
    
    "#{base_urls[blockchain.to_sym]}/#{verification_hash}"
  end
  
  # Track manufacturing
  def track_manufacturing(manufacturer, location, batch_number)
    record_event(
      :manufactured,
      "Manufactured by #{manufacturer}",
      {
        manufacturer: manufacturer,
        location: location,
        batch_number: batch_number,
        date: Date.current
      }
    )
  end
  
  # Track quality check
  def track_quality_check(inspector, passed, notes = nil)
    record_event(
      :quality_checked,
      "Quality inspection #{passed ? 'passed' : 'failed'}",
      {
        inspector: inspector,
        passed: passed,
        notes: notes,
        date: Date.current
      }
    )
  end
  
  # Track shipment
  def track_shipment(carrier, tracking_number, from_location, to_location)
    record_event(
      :shipped,
      "Shipped via #{carrier}",
      {
        carrier: carrier,
        tracking_number: tracking_number,
        from: from_location,
        to: to_location,
        date: Date.current
      }
    )
  end
  
  # Track ownership transfer
  def track_ownership_transfer(from_owner, to_owner)
    record_event(
      :ownership_transferred,
      "Ownership transferred",
      {
        from: from_owner,
        to: to_owner,
        date: Date.current
      }
    )
  end
  
  # Track certification
  def track_certification(certification_type, certifier, certificate_number)
    record_event(
      :certified,
      "Certified: #{certification_type}",
      {
        type: certification_type,
        certifier: certifier,
        certificate_number: certificate_number,
        date: Date.current
      }
    )
  end
  
  private
  
  def self.generate_blockchain_id
    "PROV-#{SecureRandom.hex(16).upcase}"
  end
  
  def generate_event_hash
    "0x#{SecureRandom.hex(32)}"
  end
  
  def write_to_blockchain
    # This would write to actual blockchain
    # For now, simulate with hash
    update!(
      verification_hash: "0x#{SecureRandom.hex(32)}",
      blockchain_status: :confirmed
    )
  end
  
  def write_event_to_blockchain(event)
    # This would write event to blockchain
    # For now, just update hash
    event.update!(blockchain_hash: "0x#{SecureRandom.hex(32)}")
  end
  
  def fetch_from_blockchain
    # This would query blockchain
    # For now, return mock data
    {
      verified: true,
      hash: verification_hash || "0x#{SecureRandom.hex(32)}",
      events: provenance_events.count
    }
  end
end

