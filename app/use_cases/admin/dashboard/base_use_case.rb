# frozen_string_literal: true

require 'dry/monads'

module Admin
  module Dashboard
    # Base Use Case for Admin Dashboard operations
    # Provides common functionality like error handling, caching, and circuit breaking
    class BaseUseCase
      include Dry::Monads[:result]

      attr_reader :admin

      def initialize(admin, circuit_breaker_config = {})
        @admin = admin
        @circuit_breaker = CircuitBreaker.new(
          failure_threshold: circuit_breaker_config[:failure_threshold] || 3,
          recovery_timeout: circuit_breaker_config[:recovery_timeout] || 15.seconds,
          monitoring_period: circuit_breaker_config[:monitoring_period] || 30.seconds
        )
      end

      protected

      def execute_with_circuit_breaker(&block)
        @circuit_breaker.run(&block)
      rescue StandardError => e
        Failure("Execution failed: #{e.message}")
      end

      def cached_fetch(key, expires_in: 15.seconds, &block)
        Rails.cache.fetch("admin_dashboard_#{key}_#{@admin.id}", expires_in: expires_in, &block)
      end
    end
  end
end