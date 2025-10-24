# frozen_string_literal: true

class NftMintingService
  def self.mint(creator:, name:, description:, nft_type:, metadata: {})
    token_id = generate_token_id
    contract_address = get_contract_address(nft_type)

    nft = Nft.create!(
      creator: creator,
      owner: creator,
      name: name,
      description: description,
      nft_type: nft_type,
      token_id: token_id,
      contract_address: contract_address,
      blockchain: :polygon,
      metadata: metadata,
      minted_at: Time.current
    )

    # Schedule async blockchain minting
    MintNftJob.perform_later(nft.id)

    nft
  end

  private

  def self.generate_token_id
    loop do
      token_id = SecureRandom.hex(32)
      break token_id unless Nft.exists?(token_id: token_id)
    end
  end

  def self.get_contract_address(nft_type)
    {
      digital_art: ENV['NFT_ART_CONTRACT'],
      collectible: ENV['NFT_COLLECTIBLE_CONTRACT'],
      limited_edition_product: ENV['NFT_PRODUCT_CONTRACT'],
      membership_pass: ENV['NFT_MEMBERSHIP_CONTRACT'],
      event_ticket: ENV['NFT_TICKET_CONTRACT'],
      loyalty_token: ENV['NFT_LOYALTY_CONTRACT'],
      certificate: ENV['NFT_CERTIFICATE_CONTRACT']
    }[nft_type.to_sym] || ENV['NFT_DEFAULT_CONTRACT']
  end
end