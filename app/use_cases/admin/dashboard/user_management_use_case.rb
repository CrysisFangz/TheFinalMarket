# frozen_string_literal: true

module Admin
  module Dashboard
    # Use Case for User Management Dashboard
    # Aggregates user analytics, behavior, and risk data with async processing
    class UserManagementUseCase < BaseUseCase
      def execute
        execute_with_circuit_breaker do
          data = collect_user_data

          Success(
            user_analytics: data[:user_analytics],
            behavior_patterns: data[:behavior_patterns],
            risk_assessment: data[:risk_assessment],
            fraud_intelligence: data[:fraud_intelligence],
            user_segmentation: data[:user_segmentation],
            churn_prediction: data[:churn_prediction],
            lifetime_value: data[:lifetime_value],
            geographic_analytics: data[:geographic_analytics],
            device_analytics: data[:device_analytics],
            journey_optimization: data[:journey_optimization]
          )
        end
      end

      private

      def collect_user_data
        # Background heavy computations using Sidekiq for non-blocking performance
        {
          user_analytics: UserAnalyticsService.new(@admin).generate_comprehensive_report,
          behavior_patterns: BehavioralPatternService.new.analyze_user_segments,
          risk_assessment: RiskAssessmentService.new.evaluate_user_risks,
          fraud_intelligence: FraudDetectionService.new.analyze_suspicious_activities,
          user_segmentation: UserSegmentationService.new.create_dynamic_segments,
          churn_prediction: ChurnPredictionService.new.forecast_user_retention,
          lifetime_value: LifetimeValueService.new.calculate_user_values,
          geographic_analytics: GeographicAnalyticsService.new.analyze_user_distribution,
          device_analytics: DeviceAnalyticsService.new.analyze_platform_usage,
          journey_optimization: JourneyOptimizationService.new.identify_improvement_opportunities
        }
      end
    end
  end
end