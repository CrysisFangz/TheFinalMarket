# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductImage, type: :model do
  let(:product) { create(:product) }
  let(:product_image) { create(:product_image, product: product) }

  describe '#schedule_thumbnail_generation' do
    it 'schedules the thumbnail generation job' do
      expect(GenerateThumbnailJob).to receive(:perform_later).with(product_image.id)
      product_image.send(:schedule_thumbnail_generation)
    end
  end

  describe 'validations' do
    it 'validates presence of image' do
      product_image.image = nil
      expect(product_image).not_to be_valid
    end

    it 'validates image size' do
      product_image.image = fixture_file_upload('large_image.jpg')
      expect(product_image).not_to be_valid
    end

    it 'validates image type' do
      product_image.image = fixture_file_upload('invalid.txt')
      expect(product_image).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to product' do
      expect(product_image.product).to eq(product)
    end
  end
end