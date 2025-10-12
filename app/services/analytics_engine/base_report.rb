module AnalyticsEngine
  class BaseReport
    attr_reader :report, :params
    
    def initialize(report, params = {})
      @report = report
      @params = params
    end
    
    def generate
      {
        report_name: report.name,
        report_type: report.report_type,
        generated_at: Time.current,
        parameters: params,
        data: generate_data,
        summary: generate_summary,
        visualizations: generate_visualizations
      }
    end
    
    protected
    
    def generate_data
      raise NotImplementedError, "Subclasses must implement generate_data"
    end
    
    def generate_summary
      {}
    end
    
    def generate_visualizations
      []
    end
    
    def date_range
      start_date = params[:start_date] || 30.days.ago.to_date
      end_date = params[:end_date] || Date.current
      start_date..end_date
    end
    
    def format_currency(cents)
      "$#{(cents / 100.0).round(2)}"
    end
    
    def format_percentage(value)
      "#{value.round(2)}%"
    end
  end
end

