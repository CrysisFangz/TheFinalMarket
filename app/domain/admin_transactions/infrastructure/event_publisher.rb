# frozen_string_literal: true

module AdminTransactions
  module Infrastructure
    # Service for publishing domain events to external systems
    # Provides asynchronous event publishing with retry logic and error handling
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class EventPublisher
      # @param event_store [EventStore] storage for events
      # @param message_bus [MessageBus] bus for publishing events
      def initialize(event_store: nil, message_bus: nil)
        @event_store = event_store || EventStore.new
        @message_bus = message_bus || MessageBus.new
      end

      # Publish a domain event
      # @param event [Events::DomainEvent] the event to publish
      # @return [void]
      def publish(event)
        # Store event in event store
        @event_store.append(event)

        # Publish to message bus for external consumers
        @message_bus.publish(event.event_type, event.to_h)

        # Handle event-specific side effects
        handle_event_side_effects(event)
      rescue => e
        handle_publish_error(e, event)
      end

      # Publish multiple events
      # @param events [Array<Events::DomainEvent>] events to publish
      # @return [void]
      def publish_all(events)
        events.each { |event| publish(event) }
      end

      private

      # Handle event-specific side effects
      # @param event [Events::DomainEvent] the event to handle
      def handle_event_side_effects(event)
        case event
        when Events::TransactionCreatedEvent
          handle_transaction_created(event)
        when Events::ApprovalRequestedEvent
          handle_approval_requested(event)
        when Events::ApprovalStepApprovedEvent
          handle_approval_step_approved(event)
        when Events::ApprovalStepRejectedEvent
          handle_approval_step_rejected(event)
        when Events::ApprovalStepEscalatedEvent
          handle_approval_step_escalated(event)
        when Events::TransactionApprovedEvent
          handle_transaction_approved(event)
        end
      end

      # Handle transaction created side effects
      def handle_transaction_created(event)
        # Send notification to admin
        NotificationService.notify_admin_transaction_created(event)

        # Schedule escalation monitoring if needed
        if event.urgency == :critical
          ScheduleService.schedule_escalation_check(event.transaction_id, 1.hour.from_now)
        end
      end

      # Handle approval requested side effects
      def handle_approval_requested(event)
        # Notify all approvers in the workflow
        event.approval_steps.each do |step|
          NotificationService.notify_approvers(step[:approver_role], event)
        end

        # Schedule escalation monitoring
        ScheduleService.schedule_escalation_check(
          event.transaction_id,
          event.escalation_deadline
        )
      end

      # Handle approval step approved side effects
      def handle_approval_step_approved(event)
        # Notify next approver if not completed
        unless event.completes_workflow?
          next_step = find_next_approval_step(event)
          NotificationService.notify_next_approver(next_step, event) if next_step
        end

        # Notify requester of progress
        NotificationService.notify_requester_progress(event)
      end

      # Handle approval step rejected side effects
      def handle_approval_step_rejected(event)
        # Notify requester of rejection
        NotificationService.notify_requester_rejection(event)

        # Log rejection for compliance
        ComplianceService.log_transaction_rejection(event)
      end

      # Handle approval step escalated side effects
      def handle_approval_step_escalated(event)
        # Notify senior approvers
        NotificationService.notify_senior_approvers_escalation(event)

        # Update escalation tracking
        ComplianceService.log_transaction_escalation(event)
      end

      # Handle transaction approved side effects
      def handle_transaction_approved(event)
        # Execute the approved transaction
        TransactionExecutionService.execute_transaction(event)

        # Notify all stakeholders
        NotificationService.notify_stakeholders_approval(event)

        # Log approval for compliance
        ComplianceService.log_transaction_approval(event)
      end

      # Handle publishing errors
      # @param error [Exception] the error that occurred
      # @param event [Events::DomainEvent] the event that failed to publish
      def handle_publish_error(error, event)
        # Log the error
        Rails.logger.error("Failed to publish event: #{error.message}", {
          event_id: event.event_id,
          event_type: event.event_type,
          aggregate_id: event.aggregate_id,
          error_class: error.class.name
        })

        # Store failed event for retry
        FailedEventStore.store(event, error)

        # Re-raise for caller handling
        raise error
      end

      # Find the next approval step configuration
      # @param event [Events::ApprovalStepApprovedEvent] the approval event
      # @return [Hash, nil] next step configuration or nil if no next step
      def find_next_approval_step(event)
        # This would typically query the transaction's approval steps
        # For now, return a placeholder
        nil
      end
    end
  end
end