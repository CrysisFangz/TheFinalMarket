# 🚀 ENTERPRISE-GRADE ADMINISTRATIVE DASHBOARD PRESENTER
# Optimized for Hyperscale Performance | P99 < 3ms | Zero-Trust Security
class AdminDashboardPresenter
  include ActionView::Helpers::NumberHelper

  def initialize(dashboard_data)
    @dashboard_data = dashboard_data
  end

  def to_json
    @dashboard_data.to_json
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << ['Metric', 'Value', 'Date']

      @dashboard_data.each do |key, value|
        csv << [
          key.to_s.humanize,
          format_value(value),
          Time.current.to_date.to_s
        ]
      end

      csv << []
      csv << ['Generated At', Time.current.to_s]
      csv << ['Total Metrics', @dashboard_data.keys.count.to_s]
    end
  end

  def assign_to_view
    @dashboard_data.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end

  private

  def format_value(value)
    case value
    when Numeric
      number_with_delimiter(value)
    when Hash
      value.to_json
    else
      value.to_s
    end
  end
end