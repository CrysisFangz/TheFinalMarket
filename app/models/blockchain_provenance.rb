# frozen_string_literal: true

# == Schema Information
#
# Table name: blockchain_provenances
#
#  id                :bigint           not null, primary key
#  product_id        :bigint           not null
#  blockchain_id     :string           not null
#  blockchain        :integer          not null
#  origin_data       :jsonb
#  verified          :boolean          default FALSE
#  verified_at       :datetime
#  verification_hash :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
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

  # Create provenance record using service object
  def self.create_for_product(product, origin_data = {})
    ProvenanceCreationService.execute!(
      product: product,
      origin_data: origin_data
    )
  end

  # Record provenance event using service object
  def record_event(event_type, description, data = {})
    ProvenanceEventService.execute!(
      provenance: self,
      event_type: event_type,
      description: description,
      data: data
    )
  end

  # Verify provenance using service object
  def verify!
    ProvenanceVerificationService.execute!(provenance: self)
  end

  # Get provenance chain
  def provenance_chain
    ProvenanceQueryService.provenance_chain_for(self)
  end

  # Get certificate
  def certificate
    ProvenanceCertificateService.certificate_for(self)
  end

  # Get verification URL
  def verification_url
    ProvenanceUrlService.verification_url_for(self)
  end

  # Get blockchain explorer URL
  def blockchain_explorer_url
    ProvenanceUrlService.explorer_url_for(self)
  end

  # Track manufacturing using service object
  def track_manufacturing(manufacturer, location, batch_number)
    ProvenanceEventService.execute!(
      provenance: self,
      event_type: :manufactured,
      description: "Manufactured by #{manufacturer}",
      data: {
        manufacturer: manufacturer,
        location: location,
        batch_number: batch_number,
        date: Date.current
      }
    )
  end

  # Track quality check using service object
  def track_quality_check(inspector, passed, notes = nil)
    ProvenanceEventService.execute!(
      provenance: self,
      event_type: :quality_checked,
      description: "Quality inspection #{passed ? 'passed' : 'failed'}",
      data: {
        inspector: inspector,
        passed: passed,
        notes: notes,
        date: Date.current
      }
    )
  end

  # Track shipment using service object
  def track_shipment(carrier, tracking_number, from_location, to_location)
    ProvenanceEventService.execute!(
      provenance: self,
      event_type: :shipped,
      description: "Shipped via #{carrier}",
      data: {
        carrier: carrier,
        tracking_number: tracking_number,
        from: from_location,
        to: to_location,
        date: Date.current
      }
    )
  end

  # Track ownership transfer using service object
  def track_ownership_transfer(from_owner, to_owner)
    ProvenanceEventService.execute!(
      provenance: self,
      event_type: :ownership_transferred,
      description: "Ownership transferred",
      data: {
        from: from_owner,
        to: to_owner,
        date: Date.current
      }
    )
  end

  # Track certification using service object
  def track_certification(certification_type, certifier, certificate_number)
    ProvenanceEventService.execute!(
      provenance: self,
      event_type: :certified,
      description: "Certified: #{certification_type}",
      data: {
        type: certification_type,
        certifier: certifier,
        certificate_number: certificate_number,
        date: Date.current
      }
    )
  end

  private

  # Generate blockchain ID using value object
  def self.generate_blockchain_id
    ProvenanceId.generate
  end

  # Generate event hash using value object
  def generate_event_hash
    EventHash.generate
  end

  # Write to blockchain using service object
  def write_to_blockchain
    BlockchainService.write_provenance(self)
  end

  # Write event to blockchain using service object
  def write_event_to_blockchain(event)
    BlockchainService.write_event(event)
  end

  # Fetch from blockchain using service object
  def fetch_from_blockchain
    BlockchainService.fetch_provenance_data(self)
  end
end