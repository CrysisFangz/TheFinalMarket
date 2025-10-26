# frozen_string_literal: true

class CustomerBehaviorPresenter
  def initialize(predictions)
    @predictions = predictions
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << ['User ID', 'Segment', 'Segment Confidence', 'Next Purchase Date',
              'Purchase Probability', 'Likely Categories', 'Personalization Factors']

      @predictions.each do |prediction|
        csv << [
          prediction[:user_id],
          prediction[:segment],
          prediction[:segment_confidence],
          prediction[:predicted_next_purchase][:expected_date],
          prediction[:predicted_next_purchase][:probability],
          prediction[:predicted_next_purchase][:likely_categories].join(', '),
          prediction[:personalization_factors].to_json
        ]
      end
    end
  end
end