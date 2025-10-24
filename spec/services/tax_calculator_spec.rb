require 'rails_helper'

RSpec.describe TaxCalculator do
  let(:tax_rate) { create(:tax_rate, rate: 10.0, included_in_price: false) }
  let(:amount_cents) { 10000 } # $100.00

  describe '.calculate_tax' do
    it 'calculates the correct tax amount' do
      expect(described_class.calculate_tax(tax_rate, amount_cents)).to eq(1000)
    end

    it 'handles zero amount' do
      expect(described_class.calculate_tax(tax_rate, 0)).to eq(0)
    end

    it 'raises error for invalid inputs' do
      expect { described_class.calculate_tax(nil, amount_cents) }.to raise_error(ArgumentError)
      expect { described_class.calculate_tax(tax_rate, -1) }.to raise_error(ArgumentError)
    end
  end

  describe '.with_tax' do
    it 'returns amount plus tax' do
      expect(described_class.with_tax(tax_rate, amount_cents)).to eq(11000)
    end
  end

  describe '.without_tax' do
    context 'when tax is not included' do
      it 'returns the original amount' do
        expect(described_class.without_tax(tax_rate, amount_cents)).to eq(amount_cents)
      end
    end

    context 'when tax is included' do
      let(:tax_rate) { create(:tax_rate, rate: 10.0, included_in_price: true) }

      it 'calculates the amount without tax' do
        expect(described_class.without_tax(tax_rate, 11000)).to eq(10000)
      end
    end
  end
end