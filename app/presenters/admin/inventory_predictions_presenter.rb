# frozen_string_literal: true

class InventoryPredictionsPresenter
  def initialize(predictions)
    @predictions = predictions
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << ['Product ID', 'Product Name', 'Current Stock', 'Predicted Demand',
              'Reorder Point', 'Optimal Order Quantity', 'Confidence']

      @predictions.each do |prediction|
        csv << [
          prediction[:product_id],
          prediction[:product_name],
          prediction[:current_stock],
          prediction[:predicted_demand],
          prediction[:reorder_point],
          prediction[:optimal_order_quantity],
          prediction[:confidence]
        ]
      end
    end
  end
end