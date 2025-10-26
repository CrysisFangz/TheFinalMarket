# frozen_string_literal: true

class SalesForecastPresenter
  def initialize(forecast)
    @forecast = forecast
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << ['Date', 'Predicted Sales', 'Lower Bound', 'Upper Bound']

      @forecast[:dates].each_with_index do |date, i|
        csv << [
          date,
          @forecast[:predictions][i],
          @forecast[:confidence_intervals][i][:lower],
          @forecast[:confidence_intervals][i][:upper]
        ]
      end
    end
  end
end