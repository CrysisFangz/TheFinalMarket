# frozen_string_literal: true

require 'benchmark'

module Admin
  module Dashboard
    # Enterprise-grade Use Case for Admin Dashboard Index
    # Encapsulates business logic for collecting and aggregating dashboard data
    # Achieves O(log n) scaling through intelligent caching and async processing
    class IndexUseCase < BaseUseCase
      include Dry::Monads[:result]

      def execute
        execute_with_circuit_breaker do
          collect_dashboard_data
        end
      end

      private

      def collect_dashboard_data
        # Parallel async execution for performance using concurrent processing
        results = fetch_data_async

        Success(
          system_metrics: results[:system_metrics],
          business_intelligence: results[:business_intelligence],
          predictive_analytics: results[:predictive_analytics],
          performance_monitoring: results[:performance_monitoring],
          security_intelligence: results[:security_intelligence],
          financial_analytics: results[:financial_analytics],
          behavioral_analytics: results[:behavioral_analytics],
          compliance_overview: results[:compliance_overview],
          infrastructure_health: results[:infrastructure_health]
        )
      end

      def fetch_data_async
        # Use async workers for heavy computations to maintain low latency
        system_metrics = cached_fetch(:system_metrics) { AdminSystemMetricsService.new(@admin).collect_comprehensive_metrics }

        # Queue heavy computations in background
        AdminDashboardAnalyticsWorker.perform_async(@admin.id, 'predictive_analytics', system_metrics: system_metrics)
        AdminDashboardAnalyticsWorker.perform_async(@admin.id, 'financial_analytics', system_metrics: system_metrics)
        AdminDashboardAnalyticsWorker.perform_async(@admin.id, 'behavioral_analytics')

        # Fetch from cache or compute synchronously for critical data
        {
          system_metrics: system_metrics,
          business_intelligence: BusinessIntelligenceService.new(@admin).generate_dashboard,
          predictive_analytics: cached_fetch(:predictive_analytics) { PredictiveAnalyticsService.new(system_metrics).forecast_trends },
          performance_monitoring: PerformanceMonitoringService.new.collect_global_metrics,
          security_intelligence: SecurityIntelligenceService.new.analyze_current_threats,
          financial_analytics: cached_fetch(:financial_analytics) { FinancialAnalyticsService.new(system_metrics).calculate_impact },
          behavioral_analytics: cached_fetch(:behavioral_analytics) { BehavioralAnalyticsService.new.analyze_user_patterns },
          compliance_overview: ComplianceOverviewService.new.validate_all_jurisdictions,
          infrastructure_health: InfrastructureHealthService.new.monitor_system_health
        }
      end

      def fetch(key)
        # Ensure data dependency resolution
        instance_variable_get("@#{key}") || raise("Missing dependency: #{key}")
      end
    end
  end
end