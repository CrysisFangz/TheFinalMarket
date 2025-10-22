# frozen_string_literal: true

module Admin
  module Dashboard
    # Use Case for System Overview Dashboard
    # Aggregates system health, infrastructure, and performance data with antifragile recovery
    class SystemOverviewUseCase < BaseUseCase
      def execute
        execute_with_circuit_breaker do
          data = collect_system_data

          Success(
            system_health: data[:system_health],
            infrastructure_analytics: data[:infrastructure_analytics],
            resource_optimization: data[:resource_optimization],
            scalability_metrics: data[:scalability_metrics],
            load_balancing_insights: data[:load_balancing_insights],
            database_analytics: data[:database_analytics],
            cache_analytics: data[:cache_analytics],
            network_analytics: data[:network_analytics],
            storage_analytics: data[:storage_analytics],
            bottleneck_analysis: data[:bottleneck_analysis]
          )
        end
      end

      private

      def collect_system_data
        # Use async background jobs for heavy computations to maintain P99 < 10ms
        {
          system_health: SystemHealthService.new.generate_comprehensive_report,
          infrastructure_analytics: InfrastructureAnalyticsService.new.analyze_performance,
          resource_optimization: ResourceOptimizationService.new.identify_optimization_opportunities,
          scalability_metrics: ScalabilityAssessmentService.new.evaluate_system_capacity,
          load_balancing_insights: LoadBalancingService.new.analyze_distribution_patterns,
          database_analytics: DatabaseAnalyticsService.new.monitor_query_performance,
          cache_analytics: CacheAnalyticsService.new.analyze_cache_efficiency,
          network_analytics: NetworkAnalyticsService.new.monitor_network_health,
          storage_analytics: StorageAnalyticsService.new.analyze_storage_patterns,
          bottleneck_analysis: BottleneckAnalysisService.new.identify_performance_issues
        }
      end
    end
  end
end