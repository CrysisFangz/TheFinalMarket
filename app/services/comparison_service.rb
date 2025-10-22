# 🚀 COMPARISON SERVICE
# Enterprise Business Logic Service for Product Comparison Operations
#
# This service encapsulates all business logic related to product comparison
# management, implementing sophisticated algorithms for comparison optimization,
# intelligent product matching, and advanced user experience enhancement.

class ComparisonService
  include ServicePattern
  include PerformanceOptimization
  include SecurityHardening
  include ObservabilityIntegration

  def execute_addition(&block)
    with_performance_monitoring do
      with_security_validation do
        execute_service_operation(:addition, &block)
      end
    end
  end

  def execute_removal(&block)
    with_performance_monitoring do
      with_security_validation do
        execute_service_operation(:removal, &block)
      end
    end
  end

  private

  def execute_service_operation(operation_type, &block)
    service_executor.execute(operation_type) do |executor|
      executor.validate_operation_context
      executor.authorize_operation
      executor.execute_business_logic(&block)
      executor.record_operation_metrics
      executor.trigger_side_effects
      executor.publish_operation_events
    end
  end

  def with_security_validation(&block)
    security_validator.validate(&block)
  end

  def service_executor
    @service_executor ||= ServiceExecutor.new
  end

  def security_validator
    @security_validator ||= SecurityValidator.new
  end
end