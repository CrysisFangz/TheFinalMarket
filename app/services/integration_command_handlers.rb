# frozen_string_literal: true

# Enterprise-grade Command Handlers for Channel Integration Operations
# Implements CQRS Command pattern for write operations
module IntegrationCommandHandlers
  # Connect Integration Command Handler
  class ConnectIntegration
    include Monitoring::Observable
    include Security::CredentialManagement

    def initialize(integration, credentials, metadata = {})
      @integration = integration
      @credentials = credentials
      @metadata = metadata
      @start_time = Time.current
    end

    def execute
      observe('integration.connect.started', integration_id: @integration.id)

      validate_credentials!
      secure_credentials!
      establish_connection!
      update_integration_state!
      trigger_initial_sync!
      record_success!

      observe('integration.connect.completed',
        integration_id: @integration.id,
        duration: elapsed_time
      )

      @integration
    rescue StandardError => e
      handle_error(e)
      raise
    end

    private

    def validate_credentials!
      unless @integration.valid_credentials?(@credentials)
        raise SecurityError, 'Invalid credentials format for integration type'
      end
    end

    def secure_credentials!
      encrypted_credentials = Security::CredentialVault.encrypt(@credentials)
      @integration.update!(credentials: encrypted_credentials)
    end

    def establish_connection!
      # Test connection before marking as active
      test_result = @integration.test_connection
      unless test_result[:success]
        raise IntegrationError, "Connection test failed: #{test_result[:message]}"
      end
    end

    def update_integration_state!
      @integration.update!(
        active: true,
        connected_at: Time.current,
        sync_status: :pending,
        health_status: :healthy,
        error_count: 0,
        last_error: nil,
        circuit_breaker_state: {
          'state' => 'closed',
          'failure_count' => 0,
          'last_failure_at' => nil,
          'next_retry_at' => nil
        }
      )
    end

    def trigger_initial_sync!
      # Schedule async initial sync
      IntegrationJobs::InitialSync.perform_async(@integration.id, @metadata)
    end

    def record_success!
      apply_event(IntegrationEvents::Connected.new(
        data: {
          integration_id: @integration.id,
          platform_name: @integration.platform_name,
          integration_type: @integration.integration_type,
          connected_at: Time.current,
          metadata: @metadata
        }
      ))
    end

    def handle_error(error)
      observe('integration.connect.failed',
        integration_id: @integration.id,
        error: error.message,
        duration: elapsed_time
      )

      apply_event(IntegrationEvents::ConnectionFailed.new(
        data: {
          integration_id: @integration.id,
          error: error.message,
          error_at: Time.current
        }
      ))
    end

    def elapsed_time
      Time.current - @start_time
    end
  end

  # Disconnect Integration Command Handler
  class DisconnectIntegration
    include Monitoring::Observable

    def initialize(integration, reason = nil, metadata = {})
      @integration = integration
      @reason = reason
      @metadata = metadata
      @start_time = Time.current
    end

    def execute
      observe('integration.disconnect.started', integration_id: @integration.id)

      gracefully_shutdown!
      update_integration_state!
      cleanup_resources!
      record_disconnection!

      observe('integration.disconnect.completed',
        integration_id: @integration.id,
        duration: elapsed_time
      )

      @integration
    rescue StandardError => e
      handle_error(e)
      raise
    end

    private

    def gracefully_shutdown!
      # Cancel any pending sync jobs
      cancel_pending_jobs!

      # Complete any in-progress operations
      complete_in_progress_operations!
    end

    def cancel_pending_jobs!
      # Cancel Sidekiq jobs for this integration
      Sidekiq::Queue.new('integrations').each do |job|
        job.delete if job.args.first == @integration.id
      end
    end

    def complete_in_progress_operations!
      # Allow current sync to complete gracefully if possible
      return unless @integration.syncing?

      # Set a timeout for graceful completion
      Timeout::timeout(30.seconds) do
        sleep 1 until !@integration.syncing?
      end
    rescue Timeout::Error
      # Force termination if graceful shutdown fails
      @integration.update!(sync_status: :paused)
    end

    def update_integration_state!
      @integration.update!(
        active: false,
        disconnected_at: Time.current,
        sync_status: :paused,
        health_status: :inactive
      )
    end

    def cleanup_resources!
      # Clear sensitive data
      @integration.update!(
        credentials: nil,
        circuit_breaker_state: nil,
        performance_metrics: nil
      )

      # Archive old events if needed
      archive_old_events!
    end

    def archive_old_events!
      # Move old events to cold storage
      IntegrationEvents::EventStore.archive_old_events(@integration.id)
    end

    def record_disconnection!
      apply_event(IntegrationEvents::Disconnected.new(
        data: {
          integration_id: @integration.id,
          platform_name: @integration.platform_name,
          disconnected_at: Time.current,
          reason: @reason,
          metadata: @metadata
        }
      ))
    end

    def handle_error(error)
      observe('integration.disconnect.failed',
        integration_id: @integration.id,
        error: error.message,
        duration: elapsed_time
      )
    end

    def elapsed_time
      Time.current - @start_time
    end
  end

  # Sync Integration Command Handler
  class SyncIntegration
    include Monitoring::Observable
    include Performance::CircuitBreaker
    include Resilience::RetryPolicy

    def initialize(integration, options = {})
      @integration = integration
      @options = options
      @start_time = Time.current
      @sync_context = {}
    end

    def execute
      observe('integration.sync.started',
        integration_id: @integration.id,
        options: @options
      )

      return if @integration.inactive?

      check_circuit_breaker!
      start_sync_process!
      execute_sync_strategy!
      complete_sync_process!
      record_success!

      observe('integration.sync.completed',
        integration_id: @integration.id,
        duration: elapsed_time,
        context: @sync_context
      )

      @integration
    rescue StandardError => e
      handle_sync_error(e)
      raise
    end

    private

    def check_circuit_breaker!
      if @integration.circuit_breaker_open?
        next_retry = @integration.circuit_breaker_state['next_retry_at']
        if next_retry && Time.current < next_retry
          raise CircuitBreakerOpenError, "Circuit breaker open until #{next_retry}"
        else
          @integration.reset_circuit_breaker!
        end
      end
    end

    def start_sync_process!
      @integration.update!(
        sync_status: :syncing,
        last_sync_started_at: Time.current,
        error_count: 0,
        last_error: nil
      )

      apply_event(IntegrationEvents::SyncStarted.new(
        data: {
          integration_id: @integration.id,
          sync_type: @options[:sync_type] || 'full',
          started_at: Time.current,
          options: @options
        }
      ))
    end

    def execute_sync_strategy!
      case @integration.integration_type.to_sym
      when :marketplace
        sync_marketplace_data!
      when :social_commerce
        sync_social_commerce_data!
      when :pos_system
        sync_pos_data!
      when :erp_system
        sync_erp_data!
      when :crm_system
        sync_crm_data!
      when :shipping
        sync_shipping_data!
      when :payment
        sync_payment_data!
      when :analytics
        sync_analytics_data!
      when :email
        sync_email_data!
      when :chat
        sync_chat_data!
      else
        raise IntegrationError, "Unsupported integration type: #{@integration.integration_type}"
      end
    end

    def complete_sync_process!
      @integration.update!(
        sync_status: :synced,
        last_sync_at: Time.current,
        last_sync_started_at: nil,
        error_count: 0,
        last_error: nil
      )

      # Update performance metrics
      update_performance_metrics!

      # Schedule next sync
      schedule_next_sync!
    end

    def update_performance_metrics!
      duration = elapsed_time
      current_metrics = @integration.performance_metrics

      new_metrics = {
        'average_response_time' => calculate_moving_average(
          current_metrics['average_response_time'],
          duration
        ),
        'p95_response_time' => calculate_p95_response_time(duration),
        'throughput' => calculate_throughput(duration),
        'error_rate' => calculate_error_rate
      }

      @integration.update!(performance_metrics: new_metrics)
    end

    def schedule_next_sync!
      next_sync_at = @integration.sync_frequency.from_now
      IntegrationJobs::ScheduledSync.perform_at(next_sync_at, @integration.id)
    end

    def record_success!
      apply_event(IntegrationEvents::SyncCompleted.new(
        data: {
          integration_id: @integration.id,
          completed_at: Time.current,
          duration: elapsed_time,
          context: @sync_context
        }
      ))
    end

    def handle_sync_error(error)
      observe('integration.sync.failed',
        integration_id: @integration.id,
        error: error.message,
        duration: elapsed_time
      )

      @integration.record_circuit_breaker_failure

      @integration.update!(
        sync_status: :failed,
        last_error: error.message,
        last_sync_started_at: nil,
        error_count: @integration.error_count + 1
      )

      apply_event(IntegrationEvents::SyncFailed.new(
        data: {
          integration_id: @integration.id,
          error: error.message,
          failed_at: Time.current,
          context: @sync_context
        }
      ))
    end

    def elapsed_time
      Time.current - @start_time
    end

    # Sync strategy implementations
    def sync_marketplace_data!
      strategy = SyncStrategies::MarketplaceSync.new(@integration, @options)
      @sync_context = strategy.execute
    end

    def sync_social_commerce_data!
      strategy = SyncStrategies::SocialCommerceSync.new(@integration, @options)
      @sync_context = strategy.execute
    end

    def sync_pos_data!
      strategy = SyncStrategies::PosSync.new(@integration, @options)
      @sync_context = strategy.execute
    end

    def sync_erp_data!
      strategy = SyncStrategies::ErpSync.new(@integration, @options)
      @sync_context = strategy.execute
    end

    def sync_crm_data!
      strategy = SyncStrategies::CrmSync.new(@integration, @options)
      @sync_context = strategy.execute
    end

    def sync_shipping_data!
      strategy = SyncStrategies::ShippingSync.new(@integration, @options)
      @sync_context = strategy.execute
    end

    def sync_payment_data!
      strategy = SyncStrategies::PaymentSync.new(@integration, @options)
      @sync_context = strategy.execute
    end

    def sync_analytics_data!
      strategy = SyncStrategies::AnalyticsSync.new(@integration, @options)
      @sync_context = strategy.execute
    end

    def sync_email_data!
      strategy = SyncStrategies::EmailSync.new(@integration, @options)
      @sync_context = strategy.execute
    end

    def sync_chat_data!
      strategy = SyncStrategies::ChatSync.new(@integration, @options)
      @sync_context = strategy.execute
    end

    # Performance calculations
    def calculate_moving_average(current_avg, new_value, alpha = 0.1)
      return new_value if current_avg.zero?
      alpha * new_value + (1 - alpha) * current_avg
    end

    def calculate_p95_response_time(duration)
      # Simplified P95 calculation - in production would use histogram
      duration * 1.2
    end

    def calculate_throughput(duration)
      return 0 if duration.zero?
      @sync_context[:records_processed].to_f / duration
    end

    def calculate_error_rate
      total_operations = @integration.sync_count + @integration.error_count
      return 0.0 if total_operations.zero?
      (@integration.error_count.to_f / total_operations) * 100
    end
  end
end