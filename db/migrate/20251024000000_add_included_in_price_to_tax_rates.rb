class AddIncludedInPriceToTaxRates < ActiveRecord::Migration[7.0]
  def change
    add_column :tax_rates, :included_in_price, :boolean, default: false
  end
end