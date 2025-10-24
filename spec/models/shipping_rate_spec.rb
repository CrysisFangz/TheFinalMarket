require 'rails_helper'

RSpec.describe ShippingRate, type: :model do
  let(:shipping_zone) { create(:shipping_zone) }
  let(:shipping_rate) { create(:shipping_rate, shipping_zone: shipping_zone) }

  describe 'validations' do
    it { should validate_presence_of(:service_level) }
    it { should validate_presence_of(:base_rate_cents) }
    it { should validate_numericality_of(:base_rate_cents).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:min_weight_grams).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:max_weight_grams).is_greater_than(:min_weight_grams).allow_nil }
    it { should validate_numericality_of(:min_delivery_days).only_integer.is_greater_than(0).allow_nil }
    it { should validate_numericality_of(:max_delivery_days).is_greater_than_or_equal_to(:min_delivery_days).allow_nil }
  end

  describe 'associations' do
    it { should belong_to(:shipping_zone) }
  end

  describe 'enums' do
    it { should define_enum_for(:service_level).with_values(economy: 0, standard: 1, express: 2, overnight: 3) }
  end

  describe 'scopes' do
    it 'returns active rates' do
      active_rate = create(:shipping_rate, active: true)
      inactive_rate = create(:shipping_rate, active: false)
      expect(ShippingRate.active).to include(active_rate)
      expect(ShippingRate.active).not_to include(inactive_rate)
    end

    it 'returns rates for service level' do
      standard_rate = create(:shipping_rate, service_level: :standard)
      economy_rate = create(:shipping_rate, service_level: :economy)
      expect(ShippingRate.for_service(:standard)).to include(standard_rate)
      expect(ShippingRate.for_service(:standard)).not_to include(economy_rate)
    end
  end

  describe 'delegated methods' do
    it 'calculates cost using service' do
      expect(shipping_rate.calculate_cost(1000)).to eq(ShippingCostCalculator.calculate(shipping_rate, 1000))
    end

    it 'returns delivery estimate using value object' do
      estimate = DeliveryEstimate.new(shipping_rate.min_delivery_days, shipping_rate.max_delivery_days)
      expect(shipping_rate.delivery_estimate).to eq(estimate.to_s)
    end

    it 'validates weight using service' do
      expect(shipping_rate.applies_to_weight?(1000)).to eq(ShippingRateValidator.applies_to_weight?(shipping_rate, 1000))
    end
  end
end