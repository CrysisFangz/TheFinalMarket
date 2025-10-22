# frozen_string_literal: true

module AdminTransactions
  module Aggregates
    # Aggregate root representing an administrative transaction with full event sourcing
    # Maintains all business logic and state through domain events
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class AdminTransaction
      # @param transaction_id [ValueObjects::TransactionId] unique transaction identifier
      def initialize(transaction_id)
        @transaction_id = transaction_id
        @events = []
        @version = 0

        # State attributes (reconstructed from events)
        @admin_id = nil
        @requested_by_id = nil
        @approvable_type = nil
        @approvable_id = nil
        @action = nil
        @reason = nil
        @justification = nil
        @amount = nil
        @urgency = nil
        @status = nil
        @compliance_flags = []
        @created_at = nil
        @updated_at = nil

        # Workflow state
        @approval_steps = []
        @current_step_index = 0
        @escalation_deadline = nil
        @approved_by_id = nil
        @approved_at = nil
        @final_comments = nil
      end

      # @return [ValueObjects::TransactionId] unique transaction identifier
      attr_reader :transaction_id

      # @return [Integer] current version of the aggregate
      attr_reader :version

      # @return [Array<Events::DomainEvent>] all events for this aggregate
      attr_reader :events

      # State accessors
      attr_reader :admin_id, :requested_by_id, :approvable_type, :approvable_id,
                  :action, :reason, :justification, :amount, :urgency, :status,
                  :compliance_flags, :created_at, :updated_at, :approval_steps,
                  :current_step_index, :escalation_deadline, :approved_by_id,
                  :approved_at, :final_comments

      # Factory method to create a new transaction
      # @param transaction_id [ValueObjects::TransactionId] unique transaction identifier
      # @param admin_id [Integer] ID of the admin creating the transaction
      # @param requested_by_id [Integer] ID of the user requesting the transaction
      # @param approvable_type [String] polymorphic type of the object being approved
      # @param approvable_id [Integer] polymorphic ID of the object being approved
      # @param action [Symbol] the action being requested
      # @param reason [String] reason for the transaction
      # @param justification [String] detailed justification for the transaction
      # @param amount [ValueObjects::Money] monetary amount if applicable
      # @param urgency [Symbol] urgency level of the transaction
      # @param compliance_flags [Array<Symbol>] compliance requirements
      # @return [AdminTransaction] new transaction instance
      def self.create(
        transaction_id:,
        admin_id:,
        requested_by_id:,
        approvable_type: nil,
        approvable_id: nil,
        action:,
        reason:,
        justification: nil,
        amount: nil,
        urgency: :medium,
        compliance_flags: []
      )
        instance = new(transaction_id)

        # Create and apply the transaction created event
        event = Events::TransactionCreatedEvent.new(
          transaction_id: transaction_id,
          admin_id: admin_id,
          requested_by_id: requested_by_id,
          approvable_type: approvable_type,
          approvable_id: approvable_id,
          action: action,
          reason: reason,
          justification: justification,
          amount: amount,
          urgency: urgency,
          compliance_flags: compliance_flags
        )

        instance.apply_event(event)
        instance
      end

      # Load aggregate from event stream
      # @param transaction_id [ValueObjects::TransactionId] unique transaction identifier
      # @param events [Array<Events::DomainEvent>] event stream for this aggregate
      # @return [AdminTransaction] reconstructed aggregate instance
      def self.from_events(transaction_id, events)
        instance = new(transaction_id)
        events.each { |event| instance.apply_event(event) }
        instance
      end

      # Request approval for this transaction
      # @param approval_steps [Array<Hash>] configured approval steps
      # @param escalation_deadline [Time] when the transaction should escalate
      def request_approval(approval_steps, escalation_deadline)
        raise InvalidStateTransition, 'Transaction already has approval workflow' if @status

        event = Events::ApprovalRequestedEvent.new(
          transaction_id: @transaction_id,
          requested_by_id: @requested_by_id,
          initial_status: ValueObjects::TransactionStatus.new(:pending_approval),
          approval_steps: approval_steps,
          escalation_deadline: escalation_deadline
        )

        apply_event(event)
      end

      # Approve the current step
      # @param approver_id [Integer] ID of the approver
      # @param comments [String] approval comments
      def approve_current_step(approver_id, comments = nil)
        validate_approver_for_current_step(approver_id)

        if last_step?
          approve_transaction(approver_id, comments)
        else
          progress_to_next_step(approver_id, comments)
        end
      end

      # Reject the current step
      # @param approver_id [Integer] ID of the approver
      # @param comments [String] rejection comments
      def reject_current_step(approver_id, comments = nil)
        validate_approver_for_current_step(approver_id)

        event = Events::ApprovalStepRejectedEvent.new(
          transaction_id: @transaction_id,
          approver_id: approver_id,
          step_index: @current_step_index,
          comments: comments
        )

        apply_event(event)
      end

      # Escalate the current step
      # @param approver_id [Integer] ID of the approver requesting escalation
      # @param comments [String] escalation comments
      def escalate_current_step(approver_id, comments = nil)
        validate_approver_for_current_step(approver_id)

        event = Events::ApprovalStepEscalatedEvent.new(
          transaction_id: @transaction_id,
          approver_id: approver_id,
          step_index: @current_step_index,
          comments: comments
        )

        apply_event(event)
      end

      # @return [Boolean] true if transaction is in a final state
      def completed?
        @status&.final? || false
      end

      # @return [Boolean] true if transaction is approved
      def approved?
        @status&.success? || false
      end

      # @return [Boolean] true if transaction is rejected or cancelled
      def rejected?
        @status&.failure? || false
      end

      # @return [Boolean] true if transaction requires approval
      def requires_approval?
        @status&.requires_approval? || false
      end

      # @return [Boolean] true if transaction is overdue for escalation
      def overdue?
        @escalation_deadline&.past? || false
      end

      # @return [Hash] current approval step configuration
      def current_step
        @approval_steps[@current_step_index]
      end

      # @return [Boolean] true if current step is the last step
      def last_step?
        @current_step_index >= @approval_steps.size - 1
      end

      # Apply an event to this aggregate (mutates state)
      # @param event [Events::DomainEvent] event to apply
      def apply_event(event)
        @events << event
        @version += 1
        @updated_at = event.occurred_at

        case event
        when Events::TransactionCreatedEvent
          apply_transaction_created(event)
        when Events::ApprovalRequestedEvent
          apply_approval_requested(event)
        when Events::ApprovalStepApprovedEvent
          apply_approval_step_approved(event)
        when Events::ApprovalStepRejectedEvent
          apply_approval_step_rejected(event)
        when Events::ApprovalStepEscalatedEvent
          apply_approval_step_escalated(event)
        when Events::TransactionApprovedEvent
          apply_transaction_approved(event)
        end
      end

      private

      # Apply transaction created event
      def apply_transaction_created(event)
        @admin_id = event.admin_id
        @requested_by_id = event.requested_by_id
        @approvable_type = event.approvable_type
        @approvable_id = event.approvable_id
        @action = event.action
        @reason = event.reason
        @justification = event.justification
        @amount = event.amount
        @urgency = event.urgency
        @compliance_flags = event.compliance_flags
        @created_at = event.occurred_at
        @updated_at = event.occurred_at
      end

      # Apply approval requested event
      def apply_approval_requested(event)
        @status = event.initial_status
        @approval_steps = event.approval_steps
        @current_step_index = 0
        @escalation_deadline = event.escalation_deadline
      end

      # Apply approval step approved event
      def apply_approval_step_approved(event)
        @current_step_index = event.next_step_index if event.next_step_index

        if last_step?
          @status = ValueObjects::TransactionStatus.new(:approved)
          @approved_by_id = event.approver_id
          @approved_at = event.occurred_at
          @final_comments = event.comments
        else
          @status = ValueObjects::TransactionStatus.new(:under_review)
        end
      end

      # Apply approval step rejected event
      def apply_approval_step_rejected(event)
        @status = ValueObjects::TransactionStatus.new(:rejected)
        @approved_by_id = event.approver_id
        @approved_at = event.occurred_at
        @final_comments = event.comments
      end

      # Apply approval step escalated event
      def apply_approval_step_escalated(event)
        @status = ValueObjects::TransactionStatus.new(:escalated)
        @approved_by_id = event.approver_id
        @approved_at = event.occurred_at
        @final_comments = event.comments
      end

      # Apply transaction approved event
      def apply_transaction_approved(event)
        @status = ValueObjects::TransactionStatus.new(:approved)
        @approved_by_id = event.approver_id
        @approved_at = event.occurred_at
        @final_comments = event.comments
      end

      # Validate approver has authority for current step
      # @param approver_id [Integer] ID of the approver to validate
      def validate_approver_for_current_step(approver_id)
        raise InvalidStateTransition, 'Transaction does not require approval' unless requires_approval?
        raise InvalidStateTransition, 'No current approval step' unless current_step

        # This would typically check against user roles/permissions
        # For now, we'll assume any admin can approve
        unless approver_id == @admin_id || approver_id == @requested_by_id
          raise UnauthorizedApprover, 'Approver does not have authority for this step'
        end
      end

      # Progress to next approval step
      def progress_to_next_step(approver_id, comments)
        event = Events::ApprovalStepApprovedEvent.new(
          transaction_id: @transaction_id,
          approver_id: approver_id,
          step_index: @current_step_index,
          next_step_index: @current_step_index + 1,
          comments: comments
        )

        apply_event(event)
      end

      # Approve the entire transaction
      def approve_transaction(approver_id, comments)
        event = Events::TransactionApprovedEvent.new(
          transaction_id: @transaction_id,
          approver_id: approver_id,
          comments: comments
        )

        apply_event(event)
      end
    end
  end
end