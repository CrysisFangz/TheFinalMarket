# frozen_string_literal: true

class ChurnRiskPresenter
  def initialize(predictions)
    @predictions = predictions
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << ['User ID', 'Churn Probability', 'Risk Factors', 'Recommended Actions']

      @predictions.each do |prediction|
        csv << [
          prediction[:user_id],
          prediction[:churn_probability],
          prediction[:risk_factors].to_json,
          prediction[:recommended_actions].join('; ')
        ]
      end
    end
  end
end