# frozen_string_literal: true

module Users
  # Presenter for user data rendering
  class UserPresenter
    include Draper::Decoratable

    def present(user, context = {})
      {
        user: format_user(user),
        metadata: build_metadata(context),
        accessibility: build_accessibility_features(context),
        performance: build_performance_metrics,
        personalization: context[:personalization_data]
      }
    end

    private

    def format_user(user)
      user.as_json
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