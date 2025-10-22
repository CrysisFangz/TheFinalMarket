# frozen_string_literal: true

module Admin
  module Dashboard
    # Presenter for Admin Dashboard Index
    # Formats and serializes dashboard data for views and APIs
    # Ensures consistent data representation and adds performance headers
    class IndexPresenter
      def initialize(data, response_time: nil, cache_status: nil)
        @data = data
        @response_time = response_time
        @cache_status = cache_status
      end

      def to_h
        {
          system_metrics: @data[:system_metrics],
          business_intelligence: @data[:business_intelligence],
          predictive_analytics: @data[:predictive_analytics],
          performance_monitoring: @data[:performance_monitoring],
          security_intelligence: @data[:security_intelligence],
          financial_analytics: @data[:financial_analytics],
          behavioral_analytics: @data[:behavioral_analytics],
          compliance_overview: @data[:compliance_overview],
          infrastructure_health: @data[:infrastructure_health]
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def set_headers(response)
        response.headers['X-Admin-Response-Time'] = @response_time.to_s + 'ms' if @response_time
        response.headers['X-Cache-Status'] = @cache_status || 'MISS'
        response.headers['X-Dashboard-Version'] = '2.0'
      end

      def to_view_data
        # Transform for HTML views, adding computed fields if needed
        to_h.merge(metadata: { generated_at: Time.current })
      end
    end
  end
end