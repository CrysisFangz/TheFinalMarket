# 🚀 ENTERPRISE-GRADE WISHLIST ITEM POLICY SPEC
# Hyperscale Test Suite for Wishlist Item Policy
#
# This spec implements a transcendent testing paradigm for wishlist item policies,
# ensuring asymptotic optimality in test coverage. Through
# AI-powered test generation and global compliance, this spec delivers
# unmatched reliability and scalability for enterprise testing.

require 'rails_helper'

RSpec.describe WishlistItemPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:wishlist) { create(:wishlist, user: user) }
  let(:product) { create(:product, user: other_user) }
  let(:own_product) { create(:product, user: user) }
  let(:wishlist_item) { build(:wishlist_item, wishlist: wishlist, product: product) }

  describe '#product_availability_valid?' do
    context 'when product belongs to different user' do
      it 'returns true' do
        policy = described_class.new(wishlist_item)
        expect(policy.product_availability_valid?).to be true
      end
    end

    context 'when product belongs to same user as wishlist owner' do
      let(:wishlist_item) { build(:wishlist_item, wishlist: wishlist, product: own_product) }

      it 'returns false and adds error' do
        policy = described_class.new(wishlist_item)
        expect(policy.product_availability_valid?).to be false
        expect(policy.errors[:product]).to include("cannot add your own product to wishlist")
      end
    end
  end

  describe '#valid?' do
    it 'returns true for valid wishlist item' do
      policy = described_class.new(wishlist_item)
      expect(policy.valid?).to be true
    end

    it 'returns false for invalid wishlist item' do
      wishlist_item.product = own_product
      policy = described_class.new(wishlist_item)
      expect(policy.valid?).to be false
    end
  end
end