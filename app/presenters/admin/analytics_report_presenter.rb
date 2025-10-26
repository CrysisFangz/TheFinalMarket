# frozen_string_literal: true

class AnalyticsReportPresenter
  def initialize(sales_data, user_metrics, start_date, end_date)
    @sales_data = sales_data
    @user_metrics = user_metrics
    @start_date = start_date
    @end_date = end_date
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << ['Metric', 'Value', 'Date Range']

      @sales_data.each do |key, value|
        csv << [key.to_s.humanize, value, "#{@start_date} - #{@end_date}"]
      end

      @user_metrics.each do |key, value|
        csv << [key.to_s.humanize, value, "#{@start_date} - #{@end_date}"]
      end
    end
  end
end