# frozen_string_literal: true

# Enterprise-grade Event Sourcing Implementation
# Provides complete audit trails and temporal queries for channel integrations
module EventSourcing
  # Base Domain Event class
  class DomainEvent
    attr_reader :id, :aggregate_id, :event_type, :data, :metadata, :created_at, :version

    def initialize(aggregate_id, data = {}, metadata = {})
      @id = SecureRandom.uuid
      @aggregate_id = aggregate_id
      @event_type = self.class.name
      @data = data.deep_symbolize_keys
      @metadata = metadata.deep_symbolize_keys
      @created_at = Time.current
      @version = 1
    end

    def event_name
      event_type.demodulize.underscore.to_sym
    end

    def to_h
      {
        id: id,
        aggregate_id: aggregate_id,
        event_type: event_type,
        event_name: event_name,
        data: data,
        metadata: metadata,
        created_at: created_at,
        version: version
      }
    end

    def to_json
      to_h.to_json
    end
  end

  # Aggregate Root mixin for event-sourced entities
  module AggregateRoot
    extend ActiveSupport::Concern

    included do
      has_many :events, class_name: 'EventSourcing::Event', foreign_key: :aggregate_id
      after_commit :publish_events, on: [:create, :update]
    end

    def apply_event(event)
      @uncommitted_events ||= []
      @uncommitted_events << event

      # Apply the event to mutate state
      apply_event_to_aggregate(event)
    end

    def apply_event_to_aggregate(event)
      # Default implementation - can be overridden in aggregates
      # This is where event data would be used to mutate aggregate state
    end

    def load_from_events(events)
      events.each { |event| apply_event_to_aggregate(event) }
    end

    def mark_events_as_committed
      @uncommitted_events = []
    end

    def uncommitted_events
      @uncommitted_events ||= []
    end

    private

    def publish_events
      return if uncommitted_events.empty?

      EventSourcing::EventPublisher.publish(uncommitted_events)
      mark_events_as_committed
    end
  end

  # Event Store for persisting domain events
  class EventStore
    class << self
      def append_events(aggregate_id, events)
        events.each do |event|
          create_event_record(event, aggregate_id)
        end
      end

      def read_events(aggregate_id, from_version = 0)
        EventSourcing::Event.where(aggregate_id: aggregate_id, version: (from_version + 1)..).order(:version)
      end

      def read_events_stream(aggregate_id)
        EventSourcing::Event.where(aggregate_id: aggregate_id).order(:version)
      end

      def get_aggregate_version(aggregate_id)
        event = EventSourcing::Event.where(aggregate_id: aggregate_id).order(version: :desc).first
        event&.version || 0
      end

      def archive_old_events(aggregate_id, older_than = 1.year.ago)
        events = EventSourcing::Event.where(aggregate_id: aggregate_id, created_at: ..older_than)
        events.update_all(archived: true)
      end

      private

      def create_event_record(event, aggregate_id)
        EventSourcing::Event.create!(
          id: event.id,
          aggregate_id: aggregate_id,
          event_type: event.event_type,
          event_name: event.event_name,
          data: event.data,
          metadata: event.metadata,
          created_at: event.created_at,
          version: event.version
        )
      end
    end
  end

  # Event Publisher for dispatching events to handlers
  class EventPublisher
    class << self
      def publish(events)
        events.each do |event|
          publish_event(event)
        end
      end

      def publish_event(event)
        # Store event in event store
        EventStore.append_events(event.aggregate_id, [event])

        # Dispatch to event handlers
        dispatch_to_handlers(event)

        # Publish to external systems if needed
        publish_to_external_systems(event)
      end

      private

      def dispatch_to_handlers(event)
        # Find and invoke event handlers
        handler_classes = find_handler_classes(event.event_name)

        handler_classes.each do |handler_class|
          invoke_handler(handler_class, event)
        end
      end

      def find_handler_classes(event_name)
        # Find handler classes for this event type
        handler_pattern = "EventHandlers::#{event_name.to_s.camelize}"
        handler_classes = []

        # Look for handler classes in the application
        ObjectSpace.each_object(Class) do |klass|
          next unless klass.name&.start_with?(handler_pattern)

          handler_classes << klass if klass.respond_to?(:handle)
        end

        handler_classes
      end

      def invoke_handler(handler_class, event)
        # Invoke handler asynchronously for better performance
        EventSourcing::EventDispatcherJob.perform_later(handler_class.to_s, event.to_json)
      rescue StandardError => e
        # Log error but don't fail the main operation
        Rails.logger.error("Failed to invoke event handler #{handler_class}: #{e.message}")
      end

      def publish_to_external_systems(event)
        # Publish to external event streaming systems if configured
        # This could be Kafka, RabbitMQ, AWS EventBridge, etc.

        return unless external_publishing_enabled?

        case event.event_type
        when /Integration/
          publish_integration_event(event)
        when /Sync/
          publish_sync_event(event)
        when /Health/
          publish_health_event(event)
        end
      end

      def publish_integration_event(event)
        # Publish integration events to external systems
        EventSourcing::ExternalEventPublisher.publish('integrations', event)
      end

      def publish_sync_event(event)
        # Publish sync events to external systems
        EventSourcing::ExternalEventPublisher.publish('syncs', event)
      end

      def publish_health_event(event)
        # Publish health events to external systems
        EventSourcing::ExternalEventPublisher.publish('health', event)
      end

      def external_publishing_enabled?
        ENV.fetch('EVENT_SOURCING_EXTERNAL_PUBLISHING', 'false') == 'true'
      end
    end
  end

  # External Event Publisher for third-party systems
  class ExternalEventPublisher
    class << self
      def publish(topic, event)
        case external_publisher_type
        when :kafka
          publish_to_kafka(topic, event)
        when :rabbitmq
          publish_to_rabbitmq(topic, event)
        when :aws_eventbridge
          publish_to_eventbridge(topic, event)
        when :webhook
          publish_to_webhook(topic, event)
        else
          # No-op for development/testing
        end
      end

      private

      def external_publisher_type
        ENV.fetch('EXTERNAL_EVENT_PUBLISHER', :none).to_sym
      end

      def publish_to_kafka(topic, event)
        # Implementation for Kafka publishing
        # Would use kafka-ruby gem or similar
      end

      def publish_to_rabbitmq(topic, event)
        # Implementation for RabbitMQ publishing
        # Would use bunny gem or similar
      end

      def publish_to_eventbridge(topic, event)
        # Implementation for AWS EventBridge publishing
        # Would use aws-sdk gem
      end

      def publish_to_webhook(topic, event)
        # Implementation for webhook publishing
        # Would use HTTP client to POST to configured webhook URLs
      end
    end
  end

  # Event model for storing events in database
  class Event < ApplicationRecord
    belongs_to :aggregate, polymorphic: true, optional: true

    validates :id, :aggregate_id, :event_type, :event_name, presence: true
    validates :data, presence: true

    serialize :data, JSON
    serialize :metadata, JSON

    scope :for_aggregate, ->(aggregate_id) { where(aggregate_id: aggregate_id) }
    scope :of_type, ->(event_type) { where(event_type: event_type) }
    scope :since, ->(timestamp) { where('created_at >= ?', timestamp) }
    scope :until, ->(timestamp) { where('created_at <= ?', timestamp) }
    scope :active, -> { where(archived: false) }

    # Create the events table migration would be:
    # create_table :events do |t|
    #   t.string :id, null: false, index: { unique: true }
    #   t.string :aggregate_id, null: false, index: true
    #   t.string :aggregate_type
    #   t.string :event_type, null: false
    #   t.string :event_name, null: false
    #   t.jsonb :data, null: false, default: {}
    #   t.jsonb :metadata, null: false, default: {}
    #   t.datetime :created_at, null: false
    #   t.integer :version, null: false, default: 1
    #   t.boolean :archived, null: false, default: false
    #   t.timestamps
    # end
  end

  # Event Handler base class
  class EventHandler
    class << self
      def handle(event)
        handler = new
        handler.public_send("handle_#{event.event_name}", event)
      rescue StandardError => e
        Rails.logger.error("Event handler error in #{self.name}: #{e.message}")
        raise
      end
    end

    protected

    def apply_event(event)
      # Default event application - override in subclasses
    end

    def project_state(event)
      # Default state projection - override in subclasses
    end

    def publish_notification(event)
      # Default notification publishing - override in subclasses
    end
  end

  # Event Dispatcher Job for async event handling
  class EventDispatcherJob
    include Sidekiq::Job

    def perform(handler_class_name, event_json)
      handler_class = handler_class_name.constantize
      event_data = JSON.parse(event_json)
      event = DomainEvent.new(event_data['aggregate_id'], event_data['data'], event_data['metadata'])

      handler_class.handle(event)
    rescue StandardError => e
      Rails.logger.error("Failed to dispatch event to #{handler_class_name}: #{e.message}")
      raise
    end
  end

  # Integration Event handlers
  module EventHandlers
    # Integration Connected Event Handler
    class IntegrationConnected < EventSourcing::EventHandler
      def handle_integration_connected(event)
        # Create read model projections
        create_integration_projection(event)

        # Send notifications
        notify_integration_connected(event)

        # Update analytics
        update_analytics(event)

        # Cache integration status
        cache_integration_status(event)
      end

      private

      def create_integration_projection(event)
        # Create or update read model for integrations
        IntegrationReadModel.find_or_create_by(
          integration_id: event.data[:integration_id]
        ).update!(
          platform_name: event.data[:platform_name],
          integration_type: event.data[:integration_type],
          connected_at: event.data[:connected_at],
          status: 'connected'
        )
      end

      def notify_integration_connected(event)
        # Send real-time notifications
        NotificationService.notify(
          "Integration #{event.data[:platform_name]} connected successfully",
          :integration,
          event.data[:integration_id]
        )
      end

      def update_analytics(event)
        # Update integration analytics
        AnalyticsService.track('integration_connected', {
          integration_type: event.data[:integration_type],
          platform_name: event.data[:platform_name],
          timestamp: event.created_at
        })
      end

      def cache_integration_status(event)
        # Cache integration status for fast queries
        CacheService.set(
          "integration:#{event.data[:integration_id]}:status",
          'connected',
          expires_in: 1.hour
        )
      end
    end

    # Integration Sync Completed Event Handler
    class IntegrationSyncCompleted < EventSourcing::EventHandler
      def handle_integration_sync_completed(event)
        # Update sync projections
        update_sync_projection(event)

        # Update performance metrics
        update_performance_metrics(event)

        # Check for anomalies
        check_for_anomalies(event)

        # Update cache
        update_sync_cache(event)
      end

      private

      def update_sync_projection(event)
        # Update read model for sync statistics
        SyncReadModel.find_or_create_by(
          integration_id: event.data[:integration_id]
        ).update!(
          last_sync_at: event.data[:completed_at],
          sync_duration: event.data[:duration],
          status: 'completed'
        )
      end

      def update_performance_metrics(event)
        # Update performance tracking
        PerformanceTracker.record(
          integration_id: event.data[:integration_id],
          metric: :sync_duration,
          value: event.data[:duration],
          timestamp: event.created_at
        )
      end

      def check_for_anomalies(event)
        # Check if sync duration indicates performance issues
        if event.data[:duration] > 300 # 5 minutes
          AnomalyDetector.detect(
            :slow_sync,
            integration_id: event.data[:integration_id],
            duration: event.data[:duration]
          )
        end
      end

      def update_sync_cache(event)
        # Update cached sync statistics
        CacheService.set(
          "integration:#{event.data[:integration_id]}:last_sync",
          {
            completed_at: event.data[:completed_at],
            duration: event.data[:duration]
          },
          expires_in: 24.hours
        )
      end
    end

    # Integration Health Changed Event Handler
    class IntegrationHealthChanged < EventSourcing::EventHandler
      def handle_integration_health_changed(event)
        # Update health projections
        update_health_projection(event)

        # Send alerts for critical issues
        send_health_alerts(event)

        # Update monitoring dashboards
        update_monitoring(event)

        # Trigger remediation if needed
        trigger_remediation(event)
      end

      private

      def update_health_projection(event)
        # Update health read model
        HealthReadModel.find_or_create_by(
          integration_id: event.data[:integration_id]
        ).update!(
          health_status: event.data[:new_health],
          last_checked: event.data[:changed_at],
          previous_status: event.data[:old_health]
        )
      end

      def send_health_alerts(event)
        # Send alerts for unhealthy states
        case event.data[:new_health].to_sym
        when :critical, :unhealthy
          AlertService.alert(
            :integration_unhealthy,
            integration_id: event.data[:integration_id],
            status: event.data[:new_health],
            timestamp: event.created_at
          )
        end
      end

      def update_monitoring(event)
        # Update monitoring systems
        MonitoringService.update_status(
          "integration:#{event.data[:integration_id]}",
          event.data[:new_health],
          event.data[:changed_at]
        )
      end

      def trigger_remediation(event)
        # Trigger automated remediation for critical issues
        if event.data[:new_health].to_sym == :critical
          RemediationService.trigger(
            :integration_critical,
            integration_id: event.data[:integration_id]
          )
        end
      end
    end
  end

  # Read Models for optimized queries
  class IntegrationReadModel < ApplicationRecord
    belongs_to :integration, class_name: 'ChannelIntegration'

    scope :connected, -> { where(status: 'connected') }
    scope :active, -> { where(active: true) }
    scope :by_type, ->(type) { where(integration_type: type) }
  end

  class SyncReadModel < ApplicationRecord
    belongs_to :integration, class_name: 'ChannelIntegration'

    scope :recent, -> { where('last_sync_at >= ?', 24.hours.ago) }
    scope :completed, -> { where(status: 'completed') }
  end

  class HealthReadModel < ApplicationRecord
    belongs_to :integration, class_name: 'ChannelIntegration'

    scope :healthy, -> { where(health_status: 'healthy') }
    scope :unhealthy, -> { where(health_status: ['unhealthy', 'critical']) }
  end
end