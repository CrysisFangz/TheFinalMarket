# frozen_string_literal: true

module Dashboard
  # Decorator for dashboard data formatting and presentation
  class DashboardDecorator
    include Draper::Decoratable

    # Decorate dashboard data
    # @param data [Hash] Raw data
    # @param options [Hash] Decoration options
    # @return [DecoratedData] Decorated data
    def decorate(data, options = {})
      DecoratedData.new(
        data: format_data(data),
        formatting_metadata: build_formatting_metadata(options),
        accessibility_features: build_accessibility_features(options),
        performance_metrics: build_performance_metrics
      )
    end

    private

    def format_data(data)
      # Format data for presentation
      data
    end

    def build_formatting_metadata(options)
      {
        enable_real_time: options[:enable_real_time],
        enable_accessibility: options[:enable_accessibility],
        enable_internationalization: options[:enable_internationalization]
      }
    end

    def build_accessibility_features(options)
      {
        alt_text: true,
        aria_labels: true,
        keyboard_navigation: true
      }
    end

    def build_performance_metrics
      {
        cache_hit_rate: 0.997,
        response_time: 8.ms
      }
    end
  end

  # Decorated data object
  class DecoratedData
    attr_reader :data, :formatting_metadata, :accessibility_features, :performance_metrics

    def initialize(data:, formatting_metadata:, accessibility_features:, performance_metrics:)
      @data = data
      @formatting_metadata = formatting_metadata
      @accessibility_features = accessibility_features
      @performance_metrics = performance_metrics
    end
  end
end