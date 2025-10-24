# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChannelProduct, type: :model do
  let(:sales_channel) { create(:sales_channel) }
  let(:product) { create(:product) }
  let(:channel_product) { create(:channel_product, sales_channel: sales_channel, product: product) }

  describe '#sync_from_product!' do
    it 'delegates to synchronization_service' do
      expect(channel_product.synchronization_service).to receive(:synchronize_from_product).and_call_original
      channel_product.sync_from_product!
    end
  end

  describe '#performance_metrics' do
    it 'caches the result' do
      expect(Rails.cache).to receive(:fetch).and_call_original
      channel_product.performance_metrics
    end
  end

  describe 'validations' do
    it 'validates presence of sales_channel' do
      channel_product.sales_channel = nil
      expect(channel_product).not_to be_valid
    end

    it 'validates presence of product' do
      channel_product.product = nil
      expect(channel_product).not_to be_valid
    end

    it 'validates uniqueness of product_id scoped to sales_channel_id' do
      other_channel_product = build(:channel_product, sales_channel: sales_channel, product: product)
      expect(other_channel_product).not_to be_valid
    end
  end

  describe 'scopes' do
    it 'filters available products' do
      expect(ChannelProduct.available).to include(channel_product)
    end
  end
end