# frozen_string_literal: true

require 'interactor'

module Dashboard
  # Use case for generating dashboard overview with real-time analytics
  # Implements CQRS query pattern for dashboard data retrieval
  class OverviewUseCase
    include Interactor

    # Execute the use case
    # @param user [User] Current user
    # @param context [Hash] Dashboard context
    # @return [Interactor::Context] Result context
    def call
      # Generate dashboard overview
      dashboard_data = generate_dashboard_overview(context.user, context.dashboard_context)

      # Decorate the data
      decorated_data = decorate_dashboard_data(dashboard_data)

      # Record analytics
      record_analytics(decorated_data)

      context.dashboard_result = DashboardResult.success(decorated_data)
    rescue StandardError => e
      context.fail!(error: e.message)
    end

    private

    def generate_dashboard_overview(user, dashboard_context)
      # Implement dashboard generation logic
      # This would query models and apply business logic
      # Placeholder for actual implementation
      { overview: 'Dashboard data for user' }
    end

    def decorate_dashboard_data(dashboard_data)
      # Use decorator to format data
      DashboardDecorator.new.decorate(dashboard_data)
    end

    def record_analytics(decorated_data)
      # Record analytics asynchronously
      DashboardAnalyticsJob.perform_async(decorated_data.to_h)
    end
  end

  # Result object
  class DashboardResult
    attr_reader :data, :error

    def self.success(data)
      new(data: data, success: true)
    end

    def self.failure(error)
      new(error: error, success: false)
    end

    def initialize(data: nil, error: nil, success: false)
      @data = data
      @error = error
      @success = success
    end

    def success?
      @success
    end
  end
end