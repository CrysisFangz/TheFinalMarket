# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Product, type: :model do
  let(:user) { create(:user) }
  let(:product) { create(:product, user: user) }

  describe '.search' do
    it 'delegates to ProductSearchService' do
      expect(ProductSearchService).to receive(:search).and_call_original
      Product.search(query: 'test')
    end
  end

  describe '#min_price' do
    it 'delegates to ProductPricingService' do
      expect(ProductPricingService).to receive(:new).with(product).and_call_original
      product.min_price
    end
  end

  describe '#max_price' do
    it 'delegates to ProductPricingService' do
      expect(ProductPricingService).to receive(:new).with(product).and_call_original
      product.max_price
    end
  end

  describe 'validations' do
    it 'validates presence of name' do
      product.name = nil
      expect(product).not_to be_valid
    end

    it 'validates format of name' do
      product.name = 'Invalid@Name'
      expect(product).not_to be_valid
    end

    it 'validates presence of price' do
      product.price = nil
      expect(product).not_to be_valid
    end
  end

  describe 'enums' do
    it 'has correct status enum' do
      expect(product.status).to eq('draft')
    end
  end
end