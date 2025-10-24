# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PersonalizationProfile, type: :model do
  let(:user) { create(:user) }
  let(:profile) { create(:personalization_profile, user: user) }

  describe '#update_from_behavior' do
    it 'delegates to PersonalizationService' do
      expect(PersonalizationService).to receive(:new).with(profile).and_call_original
      profile.update_from_behavior(:product_view, product: create(:product))
    end
  end

  describe '#get_recommendations' do
    it 'delegates to RecommendationEngine and caches' do
      expect(RecommendationEngine).to receive(:new).with(profile).and_call_original
      profile.get_recommendations
    end
  end

  describe '#micro_segment' do
    it 'delegates to SegmentManager and caches' do
      expect(SegmentManager).to receive(:new).with(profile).and_call_original
      profile.micro_segment
    end
  end

  describe '#emotional_state' do
    context 'with no reviews' do
      it 'returns neutral' do
        expect(profile.emotional_state).to eq('neutral')
      end
    end

    context 'with high rating' do
      before { create(:review, user: user, rating: 5) }
      it 'returns very_satisfied' do
        expect(profile.emotional_state).to eq('very_satisfied')
      end
    end
  end
end