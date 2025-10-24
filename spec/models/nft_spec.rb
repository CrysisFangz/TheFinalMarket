# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Nft, type: :model do
  let(:user) { create(:user) }
  let(:nft) { create(:nft, creator: user, owner: user) }

  describe '.mint' do
    it 'delegates to NftMintingService' do
      expect(NftMintingService).to receive(:mint).and_call_original
      Nft.mint(creator: user, name: 'Test NFT', description: 'Test', nft_type: :digital_art)
    end
  end

  describe '#transfer_to' do
    it 'delegates to NftTransferService' do
      new_owner = create(:user)
      expect(NftTransferService).to receive(:new).with(nft).and_call_original
      nft.transfer_to(new_owner)
    end
  end

  describe '#place_bid' do
    it 'delegates to NftBiddingService' do
      bidder = create(:user)
      expect(NftBiddingService).to receive(:new).with(nft).and_call_original
      nft.place_bid(bidder, 10000)
    end
  end

  describe '#accept_bid' do
    it 'delegates to NftBiddingService' do
      bid = create(:nft_bid, nft: nft)
      expect(NftBiddingService).to receive(:new).with(nft).and_call_original
      nft.accept_bid(bid)
    end
  end

  describe 'validations' do
    it 'validates presence of token_id' do
      nft.token_id = nil
      expect(nft).not_to be_valid
    end

    it 'validates uniqueness of token_id' do
      other_nft = build(:nft, token_id: nft.token_id)
      expect(other_nft).not_to be_valid
    end
  end

  describe 'enums' do
    it 'has correct nft_type enum' do
      expect(nft.nft_type).to eq('digital_art')
    end

    it 'has correct blockchain enum' do
      expect(nft.blockchain).to eq('polygon')
    end
  end
end