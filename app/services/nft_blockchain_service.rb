class NftBlockchainService
  attr_reader :nft

  def initialize(nft)
    @nft = nft
  end

  def metadata_uri
    Rails.logger.debug("Getting metadata URI for NFT ID: #{nft.id}")
    "ipfs://#{nft.ipfs_hash}" if nft.ipfs_hash.present?
  end

  def opensea_url
    Rails.logger.debug("Getting OpenSea URL for NFT ID: #{nft.id}")
    "https://opensea.io/assets/#{nft.blockchain}/#{nft.contract_address}/#{nft.token_id}"
  end

  def verify_authenticity
    Rails.logger.info("Verifying authenticity for NFT ID: #{nft.id}")
    # Verify on blockchain
    blockchain_data = fetch_blockchain_data

    result = {
      verified: blockchain_data[:owner] == nft.owner.wallet_address,
      contract_verified: blockchain_data[:contract] == nft.contract_address,
      token_exists: blockchain_data[:exists],
      metadata_match: blockchain_data[:metadata_uri] == metadata_uri
    }
    Rails.logger.info("Authenticity verification completed for NFT ID: #{nft.id}")
    result
  rescue StandardError => e
    Rails.logger.error("Error verifying authenticity for NFT ID: #{nft.id} - #{e.message}")
    { verified: false, contract_verified: false, token_exists: false, metadata_match: false }
  end

  private

  def fetch_blockchain_data
    # This would query the blockchain
    # For now, return mock data
    {
      owner: nft.owner.wallet_address,
      contract: nft.contract_address,
      exists: true,
      metadata_uri: metadata_uri
    }
  end
end