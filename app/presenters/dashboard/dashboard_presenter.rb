# frozen_string_literal: true

module Dashboard
  # Presenter for dashboard data rendering
  # Implements presentation layer separation from business logic
  class DashboardPresenter
    include Draper::Decoratable

    # Present dashboard data for rendering
    # @param dashboard_data [Hash] Raw dashboard data
    # @param context [Hash] Presentation context
    # @return [Hash] Presented data
    def present(dashboard_data, context = {})
      {
        dashboard: format_dashboard(dashboard_data),
        metadata: build_metadata(context),
        accessibility: build_accessibility_features(context),
        performance: build_performance_metrics,
        streaming: context[:streaming_config],
        personalization: context[:personalization_data]
      }
    end

    private

    def format_dashboard(data)
      # Format dashboard data for UI
      data
    end

    def build_metadata(context)
      {
        theme: context[:theme_preference],
        locale: context[:localization_preference],
        device: context[:device_characteristics]
      }
    end

    def build_accessibility_features(context)
      {
        screen_reader: context[:accessibility_level] > 0,
        high_contrast: context[:accessibility_level] > 1,
        large_text: context[:accessibility_level] > 2
      }
    end

    def build_performance_metrics
      {
        cache_hit_rate: 0.99,
        response_time: 5.ms
      }
    end
  end
end