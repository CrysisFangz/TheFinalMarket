require 'rails_helper'

RSpec.describe TaxRate, type: :model do
  let(:country) { create(:country) }
  let(:tax_rate) { build(:tax_rate, country: country, name: 'Standard Tax', rate: 10.0, included_in_price: false) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(tax_rate).to be_valid
    end

    it 'is invalid without a name' do
      tax_rate.name = nil
      expect(tax_rate).to_not be_valid
    end

    it 'is invalid without a rate' do
      tax_rate.rate = nil
      expect(tax_rate).to_not be_valid
    end

    it 'is invalid with rate less than 0' do
      tax_rate.rate = -1
      expect(tax_rate).to_not be_valid
    end

    it 'is invalid with rate greater than 100' do
      tax_rate.rate = 101
      expect(tax_rate).to_not be_valid
    end

    it 'is invalid with invalid included_in_price' do
      tax_rate.included_in_price = nil
      expect(tax_rate).to_not be_valid
    end
  end

  describe 'associations' do
    it 'belongs to country' do
      expect(tax_rate.country).to eq(country)
    end
  end

  describe 'scopes' do
    before do
      create(:tax_rate, active: true)
      create(:tax_rate, active: false)
    end

    it 'returns active tax rates' do
      expect(TaxRate.active.count).to eq(1)
    end

    it 'filters by country' do
      expect(TaxRate.for_country(country).count).to eq(1)
    end
  end

  describe 'methods' do
    it 'delegates calculate_tax to TaxCalculator' do
      expect(tax_rate.calculate_tax(10000)).to eq(1000)
    end

    it 'delegates with_tax to TaxCalculator' do
      expect(tax_rate.with_tax(10000)).to eq(11000)
    end

    it 'delegates without_tax to TaxCalculator' do
      expect(tax_rate.without_tax(10000)).to eq(10000)
    end
  end
end